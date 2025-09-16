#!/usr/bin/env bash

set -eo pipefail

# Include the utils library
source scripts/lib_utils.sh

CLI="docker"

MANIFEST_FILE="manifest.yaml"

IMAGE_TAG="latest"
IMAGE_FORMAT="oci"
UBUNTU_VERSION="24.04"
APP_UID="1000"

BUILD_DIR="./build"

check_for_manifest(){
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        log_error "Manifest file not found"
        exit 1
    fi
}

retrieve_name_from_manifest(){
    local name
    name=$(yq e '.name' $MANIFEST_FILE)
    echo $name
}

retrieve_registry_from_manifest(){
    local registry
    registry=$(yq e '.registry' $MANIFEST_FILE)
    echo $registry
}


clean_build_dir(){
    if [[ -d "${BUILD_DIR}" ]]; then
        log_trace "Removing existing build directory"
        rm -rf "${BUILD_DIR}"
    fi
    mkdir -p "${BUILD_DIR}"
}

hadolint_validate(){
    local hadolint_exec
    local hadolint_exit_code
    log_info "Validating Dockerfile with hadolint"
    ${CLI} pull -q ghcr.io/hadolint/hadolint:latest > /dev/null
    log_trace "$(${CLI} run --rm -i ghcr.io/hadolint/hadolint:latest hadolint -v)"

    set +e
    hadolint_exec=$(
        ${CLI} run --rm -i ghcr.io/hadolint/hadolint:latest < Containerfile \
            2>&1
    )
    hadolint_exit_code=$?
    set -e
    if [[ $hadolint_exit_code -ne 0 ]]; then
        echo -e "${WHITE_GRAY}${hadolint_exec}${NC}"
        log_error "Hadolint validation failed"
        exit 1
    else
        log_success "Hadolint validation passed"
    fi
}

buildah_build(){
    local buildah_exec
    local buildah_exit_code
    local buildah_args
    local manifest_args
    log_info "Build Containerfile for ${IMAGE_NAME}:${IMAGE_TAG}"
    log_trace "$(buildah --version)"


    # Extract build args from manifest
    buildah_args=()
    for arg in $(yq e '.build.args[]' $MANIFEST_FILE); do
        buildah_args+="--build-arg ${arg} "
    done

    log_trace "Buildah args: ${buildah_args}"

    # Loop through architectures
    for target in $(yq e '.build.targets[].name' $MANIFEST_FILE); do
        OS=$(yq e ".build.targets[] | select(.name == \"$target\") | .os" $MANIFEST_FILE)
        ARCH=$(yq e ".build.targets[] | select(.name == \"$target\") | .arch" $MANIFEST_FILE)
        # TODO: Review this to add annotations
        ANNOTATIONS=$(yq e ".build.targets[] | select(.name == \"$target\") | .annotations" $MANIFEST_FILE)

        log_info "👉 Building image for ${ARCH}"

        set +e
        buildah_exec=$(
            buildah build \
                --arch ${ARCH} \
                --os ${OS} \
                --squash \
                --pull-always \
                --format ${IMAGE_FORMAT} \
                ${buildah_args} \
                --tag docker-daemon:${IMAGE_NAME}-${ARCH}:${IMAGE_TAG}-${ARCH} \
                . \
                2>&1
        )
        buildah_exit_code=$?
        set -e

        if [[ $buildah_exit_code -ne 0 ]]; then
            log_error "Build failed for ${ARCH}"
            log_error "${buildah_exec}"
            exit 1
        else
            log_success "✅ Build completed for ${ARCH}"
        fi
    done
}

podman_save_image_to_tar(){
    local podman_exec
    local podman_exit_code
    log_info "Saving image to tar ${IMAGE_NAME}:${IMAGE_TAG}"
    log_trace "$(podman --version)"

    set +e
    podman_exec=$(
        ${CLI} save \
            --output ${BUILD_DIR}/${IMAGE_NAME}-${IMAGE_TAG}.tar \
            ${IMAGE_NAME}:${IMAGE_TAG} \
            2>&1
    )
    podman_exit_code=$?
    set -e
    if [[ $podman_exit_code -ne 0 ]]; then
        echo -e "${WHITE_GRAY}${podman_exec}${NC}"
        log_error "Saving image to tar failed"
        exit 1
    else
        log_success "Image saved to ${BUILD_DIR}/${IMAGE_NAME}-${IMAGE_TAG}.tar"
    fi
}

docker_save_all_arch_to_tar() {
    local arch
    local docker_exec
    local docker_exit_code

    log_info "🗃️ Saving all images to tar files"
    log_trace "$(docker --version)"

    for arch in $(yq e '.build.targets[].name' "$MANIFEST_FILE"); do
        log_info "📦 Saving image ${IMAGE_NAME}-${arch}:${IMAGE_TAG} to tar"

        set +e
        docker_exec=$(
            ${CLI} save \
                --output ${BUILD_DIR}/${IMAGE_NAME}-${arch}-${IMAGE_TAG}.tar \
                ${IMAGE_NAME}-${arch}:${IMAGE_TAG}-${arch} \
                2>&1
        )
        docker_exit_code=$?
        set -e

        if [[ $docker_exit_code -ne 0 ]]; then
            echo -e "${WHITE_GRAY}${docker_exec}${NC}"
            log_error "❌ Failed to save image ${arch} to tar"
            exit 1
        else
            log_success "✅ Image saved to ${BUILD_DIR}/${IMAGE_NAME}-${arch}-${IMAGE_TAG}.tar"
        fi
    done
}


dive_scan_for_all_arch() {
    local dive_scan
    local arch

    log_info "🔍 Running dive scan for all targets"
    log_trace "$(dive --version)"

    for arch in $(yq e '.build.targets[].name' "$MANIFEST_FILE"); do
        log_info "📦 Scanning ${IMAGE_NAME}-${arch}:${IMAGE_TAG}-${arch}"

        set +e
        dive_scan=$(\
            dive \
                --ci \
                --source="${CLI}" \
                "${IMAGE_NAME}-${arch}:${IMAGE_TAG}-${arch}" \
                2>&1 \
        )
        set -e

        if [[ $dive_scan == *"FAIL"* ]]; then
            echo -e "${WHITE_GRAY}${dive_scan}${NC}"
            log_error "❌ Dive scan failed for ${arch}"
            exit 1
        else
            log_success "✅ Dive scan passed for ${arch}"
        fi
    done
}

trivy_scan () {
    
    local trivy_scan_exec
    local trivy_scan_exit_code

    log_info "Running trivy scan on ${IMAGE_NAME}:${IMAGE_TAG}"
    log_trace "$(trivy --version)"

    set +e
    trivy_scan_exec=$(\
            trivy image \
            --input ${BUILD_DIR}/${IMAGE_NAME}-${IMAGE_TAG}.tar \
            --format github \
            --severity HIGH,CRITICAL \
            --exit-code 2 \
            ${IMAGE_NAME}:${IMAGE_TAG} \
            2>&1
    )
    # Detect exit code
    trivy_scan_exit_code=$?
    set -e
    if [[ $trivy_scan_exit_code -eq 2 ]]; then
        echo -e "${WHITE_GRAY}${trivy_scan_exec}${NC}"
        log_error "Trivy scan failed"
        exit 1
    elif [[ $trivy_scan_exit_code -eq 1 ]]; then
        echo -e "${WHITE_GRAY}${trivy_scan_exec}${NC}"
        log_error "Trivy scan error"
    else
        log_success "Trivy scan passed"
    fi
}

create_multiarch_manifest() {
    log_info "📦 Creating multi-arch manifest for ${IMAGE_NAME}:${IMAGE_TAG}"

    targets=$(yq e '.build.targets[].name' $MANIFEST_FILE)
    manifest_cmd="docker manifest create ${registry}:${IMAGE_TAG}"

    for target in $targets; do
        manifest_cmd+=" --amend ${registry}:${target}"
    done

    log_trace "$manifest_cmd"
    eval "$manifest_cmd"

    docker manifest push ${registry}:${IMAGE_TAG}
    log_success "🚀 Manifest pushed for tag ${IMAGE_TAG}"
}

# Main
clean_build_dir
check_for_manifest # Check for manifest file existence\
IMAGE_NAME=$(retrieve_name_from_manifest) # Retrieve image name from manifest

log_info "Starting build process"
log_trace "CLI: ${CLI}"
log_trace "IMAGE_NAME: ${IMAGE_NAME}"
log_trace "IMAGE_TAG: ${IMAGE_TAG}"
log_trace "IMAGE_FORMAT: ${IMAGE_FORMAT}"


# hadolint_validate # Validate/Lint Containerfile
buildah_build # Build Containerfile

if [[ $CLI == "podman" ]]; then
    podman_save_image_to_tar # Save image to tar (for trivy scan)
elif [[ $CLI == "docker" ]]; then
    docker_save_all_arch_to_tar # Save image to tar (for trivy scan)
else
    log_error "Invalid CLI"
    exit 1
fi

dive_scan_for_all_arch # Filesystem scan and analysis
# trivy_scan # Vulnerability scan

# Deploy to registry with skopeo using tags in manifest
registry=$(retrieve_registry_from_manifest)
for target in $(yq e '.build.targets[].name' $MANIFEST_FILE); do
    skopeo copy docker-daemon:${IMAGE_NAME}-${target}:${IMAGE_TAG}-${target} \
        docker://${registry}:${IMAGE_TAG}-${target}
done

create_multiarch_manifest