# LLM Playground — How To Use

## Rules for #Playground blocks

1. **Everything must be inline.** Functions, structs, and variables defined outside a `#Playground` block are NOT accessible from inside it. Each block is its own isolated scope.

2. **`@Generable` types are the exception.** Types marked `@Generable` at file scope ARE visible inside blocks. These are compile-time macros, not runtime — they work.

3. **Use `print()` for output.** Each `print()` call shows inline in the Canvas next to the line that produced it. This is how you see results without expanding history.

4. **One `#Playground("Name")` per tab.** Each block shows up as a separate tab in the Canvas. Use this for separate test categories.

5. **`import Playgrounds` is required.** Wrap playground blocks in `#if canImport(Playgrounds)` / `import Playgrounds`.

6. **`import FoundationModels` goes at file scope.** Wrap the whole file in `#if canImport(FoundationModels)`.

## Template

```swift
#if canImport(FoundationModels)
import FoundationModels

@Generable
struct MyResult {
    @Guide(description: "...")
    var output: String
}

#if canImport(Playgrounds)
import Playgrounds

#Playground("My Test") {
    // ALL logic inline here — no external function calls
    let session = LanguageModelSession(instructions: Instructions("..."))
    let r = try await session.respond(to: "...", generating: MyResult.self)
    print(r.content.output)
}

#endif
#endif
```

## Common mistakes

- **DO NOT** define helper functions outside blocks and call them from inside — they won't be found
- **DO NOT** define test data arrays outside blocks — not accessible
- **DO NOT** return bare arrays/values expecting Canvas to display them — use `print()`
- **DO** duplicate code across blocks if needed — inline is the only way
- **DO** keep `@Generable` types at file scope — they work across blocks

## Opening the playground

1. Open `widget/Playground/Package.swift` in Xcode
2. Navigate to the `.swift` file you want to test
3. Editor → Canvas (Opt+Cmd+Return)
4. Tabs at top of Canvas switch between `#Playground` blocks
