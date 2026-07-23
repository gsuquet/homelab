#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROLES_DIR="${REPO_ROOT}/ansible/roles"
DOCS_DIR="${REPO_ROOT}/docs/reference/ansible-roles"

mkdir -p "${DOCS_DIR}"

echo "Generating Ansible role documentation..."

for role_path in "${ROLES_DIR}"/*; do
    if [ ! -d "${role_path}" ]; then
        continue
    fi

    role_name="$(basename "${role_path}")"
    role_doc_dir="${DOCS_DIR}/${role_name}"
    role_doc_file="${role_doc_dir}/index.md"
    mkdir -p "${role_doc_dir}"

    # Build generated markdown block
    gen_content="### Tasks Overview\n\n"
    if [ -f "${role_path}/tasks/main.yml" ]; then
        gen_content+="Tasks defined in \`tasks/main.yml\`:\n\n"
        while IFS= read -r line || [ -n "${line}" ]; do
            if [[ "${line}" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.+) ]]; then
                task_name="${BASH_REMATCH[1]}"
                task_name="${task_name%\"}"
                task_name="${task_name#\"}"
                task_name="${task_name%\'}"
                task_name="${task_name#\'}"
                gen_content+="- ${task_name}\n"
            fi
        done < "${role_path}/tasks/main.yml"
    else
        gen_content+="*No tasks defined (or legacy role).*\n"
    fi

    gen_content+="\n### Variables & Defaults\n\n"
    if [ -f "${role_path}/defaults/main.yml" ]; then
        gen_content+="\`defaults/main.yml\`:\n\n\`\`\`yaml\n"
        gen_content+="$(cat "${role_path}/defaults/main.yml")\n\`\`\`\n"
    elif [ -f "${role_path}/vars/main.yml" ]; then
        gen_content+="\`vars/main.yml\`:\n\n\`\`\`yaml\n"
        gen_content+="$(cat "${role_path}/vars/main.yml")\n\`\`\`\n"
    else
        gen_content+="*No default variables configured.*\n"
    fi

    # Create target markdown file if it does not exist
    if [ ! -f "${role_doc_file}" ]; then
        cat <<EOF > "${role_doc_file}"
# Ansible Role: ${role_name}

[<- Back to Ansible Roles Overview](../index.md)

Documentation for the \`${role_name}\` Ansible role.

<!-- BEGIN_ANSIBLE_DOCS -->
<!-- END_ANSIBLE_DOCS -->
EOF
    fi

    # Replace content between markers
    tmp_file="$(mktemp)"
    printf "%b" "${gen_content}" > "${tmp_file}.gen"
    awk -v gen_file="${tmp_file}.gen" '
    /<!-- BEGIN_ANSIBLE_DOCS -->/ {
        print $0;
        while ((getline line < gen_file) > 0) print line;
        close(gen_file);
        skip=1;
        next;
    }
    /<!-- END_ANSIBLE_DOCS -->/ {
        skip=0;
    }
    !skip { print $0 }
    ' "${role_doc_file}" > "${tmp_file}"

    mv "${tmp_file}" "${role_doc_file}"
    rm -f "${tmp_file}.gen"
done

echo "Ansible role docs generation complete."
