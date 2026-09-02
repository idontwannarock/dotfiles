# Lens: design

Is the structure right — and could it be simpler?

Two questions that turn out to be one. Most unnecessary complexity is a data
model that forced it, and most special cases are an invariant the types never
expressed. Behavioural bugs belong to `correctness.md`; this lens is about the
shape that keeps producing them.

## Simplicity

- **Special cases.** Find the `if`/`else` branches. Which are real business
  logic, and which are patches over a structure that did not fit? A better data
  structure makes a special case disappear rather than handling it.
- **Nesting.** More than three levels of indentation is a signal the function
  is doing several jobs.
- **Concept count.** State what the change does in one sentence. Then count the
  concepts the implementation introduced to do it. Could it be half?
- **Speculative structure.** Abstractions with one implementation, options
  nobody set, extension points nothing extends. Complexity that buys nothing
  today is a cost with no purchase.
- **Data structures first.** Good data structures with dull algorithms beat
  clever algorithms over bad ones. Ask what the core data is, who owns it, who
  mutates it, and whether it is being copied or converted without cause.

## Invariants and encapsulation

- **What must always be true** of this type, and is it written down anywhere
  the compiler can see? An invariant maintained by discipline is a comment
  wearing a costume.
- **Illegal states.** Can an invalid instance be constructed? Can the invariant
  be broken from outside — a public setter, an exposed mutable collection, a
  field that two other fields must agree with?
- **Construction.** Is validation at the boundary where the value enters, or
  scattered across every use site?
- **Interface size.** Is what the type exposes minimal and complete, or does it
  leak implementation the caller must know about to use it correctly?
- **Anaemic types.** A bag of public fields with the behaviour living
  elsewhere pushes invariant maintenance onto every caller.

## Compatibility

- Does the change alter behaviour existing callers depend on — a signature, a
  return shape, a default, an error type, a file format, an exit code?
- Existing callers include ones outside this repo. Breaking them is a defect no
  matter how much better the new design is.
- When a break is genuinely required, say what the migration is.

## How to report

Say what to remove, not just that something is complex. Every suggestion pays
its own way: name the special case that disappears, the branch that collapses,
the invalid state that stops being representable. A restructuring that only
moves code sideways is not an improvement.

Weigh the cost. A simpler type with fewer guarantees can beat an elaborate one
that tries to prove too much. If the pragmatic answer is "leave it", say so.
