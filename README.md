## :lizard: :id: **zig uuid**

[![CI][ci-shield]][ci-url]
[![Docs][docs-shield]][docs-url]
[![License][license-shield]][license-url]
[![Resources][resources-shield]][resources-url]

### Zig implementation of [UUID versions from 1 to 7](https://www.ietf.org/archive/id/draft-peabody-dispatch-new-uuid-format-04.html).

#### :rocket: Usage

1. Add `uuid` as a dependency in your `build.zig.zon`.

    <details>

    <summary><code>build.zig.zon</code> example</summary>

    ```zig
    .{
        .name = "<name_of_your_program>",
        .version = "<version_of_your_program>",
        .dependencies = .{
            .uuid = .{
                .url = "https://github.com/tensorush/zig-uuid/archive/refs/tags/<git_tag>.tar.gz",
                .hash = "<package_hash>",
            },
        },
    }
    ```

    If unsure what to fill out for `<package_hash>`, set it to `12200000000000000000000000000000000000000000000000000000000000000000` and Zig will tell you the correct value in an error message.

    </details>

2. Add `uuid` as a module in your `build.zig`.

    <details>

    <summary><code>build.zig</code> example</summary>

    ```zig
    const uuid = b.dependency("uuid", .{});
    exe.addModule("uuid", uuid.module("uuid"));
    ```

    </details>

<!-- MARKDOWN LINKS -->

[ci-shield]: https://img.shields.io/github/actions/workflow/status/tensorush/zig-uuid/ci.yaml?branch=main&style=for-the-badge&logo=github&label=CI&labelColor=black
[ci-url]: https://github.com/tensorush/zig-uuid/blob/main/.github/workflows/ci.yaml
[docs-shield]: https://img.shields.io/badge/click-F6A516?style=for-the-badge&logo=zig&logoColor=F6A516&label=docs&labelColor=black
[docs-url]: https://tensorush.github.io/zig-uuid
[license-shield]: https://img.shields.io/github/license/tensorush/zig-uuid.svg?style=for-the-badge&labelColor=black
[license-url]: https://github.com/tensorush/zig-uuid/blob/main/LICENSE.md
[resources-shield]: https://img.shields.io/badge/click-F6A516?style=for-the-badge&logo=zig&logoColor=F6A516&label=resources&labelColor=black
[resources-url]: https://github.com/tensorush/Awesome-Languages-Learning#lizard-zig
