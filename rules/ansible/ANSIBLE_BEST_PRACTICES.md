# Ansible Best Practices

version: 2
status: review

This document defines Ansible Best Practices with the goal to provide clear instructions for agentic coding. Always confirm with the agent the clarity of the rules expressed here with the following prompt:

```prompt
Obey to `ANSIBLE_BEST_PRACTICES.md` document for information about Ansible Best Practices. You HAVE TO obey the document without exceptions. Confirm or enumerate points not clear or wrong from your perspective.
```

## Keep it simple

1. Prefer simplicity over complexity

2. Always use `ansible.builtin` modules for generic operations

3. Any need to `reinvent the wheel` must be strictly explained with information why regular tools can't be applied

## Dependencies

1. Use `requirements.yml` file for all Ansible dependencies. Always specify version or version range.

    ```yaml
    collections:
        - name: community.general
        version: ">=8.0.0"
        - name: ansible.posix
        version: "1.5.4"
    ```

2. Use `requirements.txt` file for all Python dependencies. Always specify version or version range.

3. Always use Python virtual environment - use `.venv` in project directory. Never create it in home directory.

4. Add `.venv` directory to `.gitignore`

## Variables

1. Always use `ansible.builtin.validate_argument_spec` module to validate arguments

2. Use inline `ansible.builtin.validate_argument_spec` module's specification

   ```yaml
   - name: Validate role arguments
     ansible.builtin.validate_argument_spec:
       argument_spec:
         myapp_port:
           type: int
           required: true
         myapp_host:
           type: str
           default: "localhost"
   ```

3. Prefix all variables with role's name

4. Use `loop_control: { loop_var: role_name_item }` instead of the default `item`. Note `role_name` is a placeholder - replace with actual role's name.

   ```yaml
   - name: Process items
     ansible.builtin.debug:
       msg: "{{ myapp_item }}"
     loop: "{{ myapp_items }}"
     loop_control:
       loop_var: myapp_item
   ```

5. Beware that each `hosts:` block inside of the playbook has isolated variable scope.

## Sensitive data

1. Always store sensitive data externally

2. Never commit plain text secrets – Any passwords, keys, tokens, or API secrets must not be stored in the repository.  

3. Use environment variables or a cloud secret manager; reference them in the playbook via `env_lookup` or `lookup('env', 'MY_SECRET')`.  

4. Keep secrets out of logs. Avoid printing secrets with `debug`. Use the `no_log: true` flag on tasks that handle secrets.  

5. Document the secret source – In the role/playbook's `README.md`; note where each secret should be stored and how it is retrieved.  

## Role invocation

1. Always use `include_role`

   ```yaml
   - name: Include database role
     ansible.builtin.include_role:
       name: database
     vars:
       database_port: 5432
   ```

2. Never use `import_role` as import does not provide any kind of variable isolation.

3. Use `roles` only on top of the play with caution, knowing that it's statically linked into the play.

## Code semantics

1. Always use regular Ansible Linter

2. Always use fully-qualified collection names (FQCN) in Ansible content

3. Avoid shell/command when possible. Encourage the use of native modules (ansible.builtin.copy, ansible.builtin.template, etc.).

4. Use become instead of sudo. Use `become: true` in roles or plays that need privilege escalation.

5. Keep debug for troubleshooting only; remove or guard it with a tag.

## Idempotency

1. Every task should be idempotent; if you need a non-idempotent operation, clearly document it.

2. If a task must run every time (e.g., a reset operation), document the side-effects and, if possible, provide a force parameter.

## Long-Running Tasks

1. Use `async` and `poll` to avoid blocking the Ansible controller.

2. Prefer `until:` with a short timeout over a long `async` job whenever possible.

3. Add a descriptive message to the `async_status` task so reviewers know what is happening.

## Testing

1. Use Molecule for role testing and ansible-test for collection testing

2. Use Podman to create test time targets

3. Test idempotency - ensure tasks can run multiple times without changing state

4. Test different scenarios - success cases, error handling, and edge cases

5. Include syntax validation (`ansible-playbook --syntax-check`) in your testing pipeline

6. Use `--check` mode (dry-run) to validate changes before applying them

## Documentation

1. Each playbook should include a README.md that describes the playbook’s purpose, required variables (with defaults), and any external prerequisites.

2. Each role should include a README.md with usage examples and variable list.
