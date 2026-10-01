# wrfkit documentation

wrfkit documentation is organized around the job a reader is trying to do,
rather than around the source-code layout.

| Goal | Document |
| --- | --- |
| Get a single-node research run working | [Single-node research guide](single-node-guide.md) |
| Check support and validation status | [Validation matrix](validation.md) |
| Learn the important limitations before a long run | [Caveats and safe patterns](caveats.md) |
| Understand implementation choices | [Design notes](design.md) |
| Reproduce the bundled test case | [Athens smoke case](../cases/athens-smoke/README.md) |

> [!NOTE]
> The layout follows the Diátaxis idea of separating goal-oriented how-to
> material from reference and explanation. The repository README is the entry
> point; these pages contain the operational detail.

## Reading path

New users should start with the [single-node research guide](single-node-guide.md).
It gives one complete path from environment setup to WRF output.

Before adapting the smoke case into a real experiment, read
[caveats.md](caveats.md). It distinguishes software/workflow validation from
scientific experiment design.

For development work, use [validation.md](validation.md) to see which execution
paths are empirically validated and [design.md](design.md) for the architecture
behind them.

## Documentation conventions

Commands are shown from the repository root unless a section says otherwise.
Examples use native GitHub Markdown, including compact tables and a small number
of alerts, so the pages remain readable directly in the GitHub repository
without requiring a separate documentation site.
