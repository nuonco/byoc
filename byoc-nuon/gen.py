import datetime
import os


def generate_inputs():
    for _, _, files in os.walk("./inputs-gen"):
        input_files = [f for f in files if ".toml" in f and f[0].isdigit()]

    lines = [f"# generated on: {datetime.datetime.now(datetime.UTC)}\n\n"]
    for i, file in enumerate(sorted(input_files)):
        lines += [
            f"# {file}",
            "\n",
        ]
        with open(f"./inputs/{file}", "r") as openfile:
            lines += openfile.readlines()
        if i < len(input_files) - 1:
            lines += ["\n\n"]

    with open("./inputs.toml", "w+") as openfile:
        for l in lines:
            openfile.write(l)


if __name__ == "__main__":
    generate_inputs()
