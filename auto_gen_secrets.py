import base64
import os.path
import secrets
import string
import sys
import uuid

import yaml


# Help with YAML formatting comes from here
# https://reorx.com/blog/python-yaml-tips/
class IndentDumper(yaml.Dumper):
    def increase_indent(self, flow=False, indentless=False):
        return super(IndentDumper, self).increase_indent(flow, False)


def gen_secret(sec_len=20):
    valid_chars = string.ascii_letters + string.digits + '!$^&*()'
    return ''.join(secrets.choice(valid_chars) for _ in range(sec_len))


def gen_b64_secret(sec_len=20):
    unencoded_secret = gen_secret(sec_len)
    unencoded_bytes = unencoded_secret.encode('utf-8')
    return base64.b64encode(unencoded_bytes).decode('utf-8')


def gen_apikey():
    return str(uuid.uuid4())


def load_yaml(path):
    with open(path, 'r') as file:
        return yaml.safe_load(file)


def dump_yaml(path, data):
    with open(path, 'w+') as file:
        yaml.dump(data, file, Dumper=IndentDumper, sort_keys=False)


def main():
    sqlalchemy_uri = ''
    if len(sys.argv) > 1:
        sqlalchemy_uri = sys.argv[1]

    main_path = "/home/scot4/scot4"

    env_sec_path = f"{main_path}/scot4/secret-skeletons/secrets.yaml"
    flair_sec_path = f"{main_path}/scot4/secret-skeletons/flair-secrets.yaml"
    nats_sec_path = f"{main_path}/scot4/secret-skeletons/nats-secrets.yaml"

    required_paths = [env_sec_path, flair_sec_path, nats_sec_path]
    missing = [path for path in required_paths if not os.path.isfile(path)]
    if missing:
        missing_list = ", ".join(missing)
        print(f"ERR: Missing placeholder secret file(s): {missing_list}")
        sys.exit(1)

    env_sec = load_yaml(env_sec_path)
    flair_sec = load_yaml(flair_sec_path)
    nats_sec = load_yaml(nats_sec_path)

    for item in env_sec["stringData"].keys():
        if item == "SQLALCHEMY_DATABASE_URI":
            if sqlalchemy_uri != '':
                env_sec["stringData"][item] = sqlalchemy_uri
        elif item == "ENRICHMENT_PASSWORD":
            env_sec["stringData"][item] = "UPDATE-ME"
        elif item in ["FIRST_SUPERUSER_APIKEY", "FLAIR_API_KEY"]:
            env_sec["stringData"][item] = gen_apikey()
        elif item == "MCP_OAUTH_SECRET_KEY":
            env_sec["stringData"][item] = gen_b64_secret(32)
        else:
            env_sec["stringData"][item] = gen_secret()

    db_password = env_sec["stringData"]["API_DB_PASSWORD"]
    if sqlalchemy_uri == "":
        env_sec["stringData"]["SQLALCHEMY_DATABASE_URI"] = env_sec["stringData"]["SQLALCHEMY_DATABASE_URI"].replace(
            "PLACEHOLDER",
            db_password,
        )

    flair_sec["stringData"]["S4FLAIR_ADMIN_PASS"] = gen_secret()
    flair_sec["stringData"]["FLAIR_DB_PASSWORD"] = gen_secret()
    flair_sec["stringData"]["S4FLAIR_MOJO_SECRETS"] = gen_secret()
    flair_sec["stringData"]["S4FLAIR_MYSQL_URI"] = (
        f"mariadb://flair:{flair_sec['stringData']['FLAIR_DB_PASSWORD']}@scot4-flair-db-service/flair"
    )
    flair_sec["stringData"]["S4FLAIR_SCOT_API_KEY"] = env_sec["stringData"]["FIRST_SUPERUSER_APIKEY"]
    flair_sec["stringData"]["S4FLAIR_FLAIR_API_KEY"] = env_sec["stringData"]["FLAIR_API_KEY"]

    nats_sec["stringData"]["AUTH_CALLOUT_PASSWORD"] = gen_secret()
    nats_sec["stringData"]["API_SERVICE_PASSWORD"] = gen_secret()
    nats_sec["stringData"]["FLAIR_SERVICE_PASSWORD"] = gen_secret()
    nats_sec["stringData"]["NATS_AUTH_ISSUER_SEED"] = "UPDATE-ME"
    nats_sec["stringData"]["NATS_AUTH_XKEY_SEED"] = "UPDATE-ME"

    dump_yaml(f"{main_path}/scot4/auto_gen_secrets.yaml", env_sec)
    dump_yaml(f"{main_path}/scot4/auto_gen_flair_secrets.yaml", flair_sec)
    dump_yaml(f"{main_path}/scot4/auto_gen_nats_secrets.yaml", nats_sec)

    help_message = """
    Secrets created for SCOT4 API, Flair, and NATS. To install the secrets with kubectl:

        FIRST - Populate the secrets for DB credentials, enrichment password, and NATS seeds
        kubectl -n scot4 apply -f scot4/auto_gen_secrets.yaml
        kubectl -n scot4 apply -f scot4/auto_gen_flair_secrets.yaml
        kubectl -n scot4 apply -f scot4/auto_gen_nats_secrets.yaml
    """
    # print(help_message)


if __name__ == "__main__":
    main()
