# Claude Prompt Engineering Reference Guide

> A comprehensive reference guide for crafting effective prompts with Claude, based on Anthropic's official documentation.

**Source:** [Claude Prompt Engineering Documentation](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview)

---

## Table of Contents

1. [Be Clear, Direct, and Detailed](#1-be-clear-direct-and-detailed)
2. [Use Examples (Multishot Prompting)](#2-use-examples-multishot-prompting)
3. [Let Claude Think (Chain of Thought)](#3-let-claude-think-chain-of-thought)
4. [Use XML Tags to Structure Prompts](#4-use-xml-tags-to-structure-prompts)
5. [Chain Complex Prompts](#5-chain-complex-prompts)
6. [Combining Techniques](#6-combining-techniques)
7. [Quick Reference](#7-quick-reference)

---

## 1. Be Clear, Direct, and Detailed

### Core Principle

Think of Claude as a **brilliant but very new employee (with amnesia)** who needs explicit instructions. Like any new employee, Claude does not have context on your norms, styles, guidelines, or preferred ways of working.

### The Golden Rule of Clear Prompting

> Show your prompt to a colleague, ideally someone who has **minimal context** on the task, and ask them to follow the instructions. If they're confused, Claude will likely be too.

### Three Key Practices

#### 1. Give Claude Contextual Information

Claude performs better with more context. Include:

- **Purpose**: What the task results will be used for
- **Audience**: Who the output is meant for
- **Workflow**: Where this task fits in the larger process
- **Success criteria**: What a successful completion looks like

#### 2. Be Specific About What You Want

If you want Claude to:
- Output only code and nothing else → say so
- Follow a specific format → specify it explicitly
- Avoid certain content → clearly state constraints

#### 3. Provide Instructions as Sequential Steps

Use numbered lists or bullet points to ensure Claude carries out tasks exactly as intended:

```
1. Read the document
2. Extract all dates mentioned
3. Format dates as ISO 8601 (YYYY-MM-DD)
4. Output only the dates, one per line
```

---

## 2. Use Examples (Multishot Prompting)

### Why Use Examples?

Examples are your **secret weapon** for getting Claude to generate exactly what you need.

| Benefit | Description |
|---------|-------------|
| **Accuracy** | Examples reduce misinterpretation of instructions |
| **Consistency** | Examples enforce uniform structure and style |
| **Performance** | Well-chosen examples boost ability to handle complex tasks |

### Power Up Your Prompts

> **Include 3-5 diverse, relevant examples** to show Claude exactly what you want. More examples = better performance, especially for complex tasks.

### Crafting Effective Examples

For maximum effectiveness, ensure your examples are:

| Quality | Description |
|---------|-------------|
| **Relevant** | Mirror your actual use case |
| **Diverse** | Cover edge cases and potential challenges; vary enough to avoid unintended patterns |
| **Clear** | Wrapped in `<example>` tags (or nested in `<examples>` tags) for structure |

### Example Template

```xml
<examples>
  <example>
    <input>Customer feedback: "The product is okay but shipping took forever."</input>
    <output>Sentiment: neutral, Issue: shipping</output>
  </example>
  <example>
    <input>Customer feedback: "Absolutely love it! Will buy again!"</input>
    <output>Sentiment: positive, Issue: none</output>
  </example>
  <example>
    <input>Customer feedback: "Broken on arrival. Terrible quality."</input>
    <output>Sentiment: negative, Issue: product quality</output>
  </example>
</examples>

Now analyze this feedback:
<input>{{USER_FEEDBACK}}</input>
```

### Pro Tips

- Ask Claude to **evaluate your examples** for relevance, diversity, or clarity
- Have Claude **generate more examples** based on your initial set
- Examples are especially effective for **structured outputs** and **specific formats**

---

## 3. Let Claude Think (Chain of Thought)

### What is Chain of Thought (CoT)?

A technique that encourages Claude to break down problems step-by-step, leading to more accurate and nuanced outputs.

### When to Use CoT

Use CoT for tasks that a **human would need to think through**:
- Complex math problems
- Multi-step analysis
- Writing complex documents
- Decisions with many factors
- Research and problem-solving

### Benefits

| Benefit | Description |
|---------|-------------|
| **Accuracy** | Stepping through problems reduces errors |
| **Coherence** | Structured thinking leads to well-organized responses |
| **Debugging** | Seeing Claude's thought process helps identify unclear prompts |

### Trade-offs

- **Increased output length** may impact latency
- **Not all tasks require in-depth thinking** — use CoT judiciously

### Three Levels of CoT Prompting

#### Level 1: Basic Prompt

Simply include "Think step-by-step" in your prompt.

```
Please analyze this data. Think step-by-step before giving your answer.
```

**Limitation**: Lacks guidance on *how* to think, especially for task-specific workflows.

#### Level 2: Guided Prompt

Outline specific steps for Claude to follow.

```
Please analyze this data by:
1. First, identify the key trends
2. Then, note any anomalies
3. Finally, provide your conclusion

Think through each step before writing your final answer.
```

**Limitation**: Lacks structuring to easily separate thinking from the answer.

#### Level 3: Structured Prompt (Recommended)

Use XML tags to separate reasoning from the final answer.

```xml
Please analyze the data in <data> tags below.

<data>
{{DATA}}
</data>

Use the following format for your response:

<thinking>
Step 1: Identify key trends...
Step 2: Note any anomalies...
Step 3: Form conclusion...
</thinking>

<answer>
Your final, concise answer here.
</answer>
```

### Critical Reminder

> **Always have Claude output its thinking. Without outputting its thought process, no thinking occurs!**

---

## 4. Use XML Tags to Structure Prompts

### Why Use XML Tags?

When prompts involve multiple components like context, instructions, and examples, XML tags are a **game-changer**.

| Benefit | Description |
|---------|-------------|
| **Clarity** | Clearly separate different parts of your prompt |
| **Accuracy** | Reduce errors from misinterpretation |
| **Flexibility** | Easily find, add, remove, or modify parts |
| **Parseability** | Easier to extract specific parts of responses |

### XML Tagging Best Practices

#### 1. Be Consistent

Use the same tag names throughout your prompts, and refer to them by name:

```
Using the contract in <contract> tags, please extract...
```

#### 2. Nest Tags

Use nested tags for hierarchical content:

```xml
<examples>
  <example>
    <input>...</input>
    <output>...</output>
  </example>
</examples>
```

### Common XML Tags

| Tag | Purpose |
|-----|---------|
| `<instructions>` | Main task instructions |
| `<context>` | Background information |
| `<example>` / `<examples>` | Multishot examples |
| `<thinking>` | Chain of thought reasoning |
| `<answer>` | Final response |
| `<formatting>` | Output format requirements |
| `<constraints>` | Things to avoid |

### Example: Structured Prompt

```xml
<context>
You are a financial analyst preparing a quarterly report for executives.
</context>

<task>
Analyze the revenue data in <data> tags and prepare a summary.
</task>

<data>
Q1 2024: $1.2M
Q2 2024: $1.5M
Q3 2024: $1.4M
Q4 2024: $1.8M
</data>

<formatting>
- Use bullet points
- Include year-over-year growth percentage
- Keep under 200 words
</formatting>

<constraints>
- Do not include raw numbers in the summary
- Do not make predictions beyond the data provided
</constraints>

Please provide your response in <summary> tags.
```

---

## 5. Chain Complex Prompts

### What is Prompt Chaining?

Breaking down complex tasks into smaller, manageable subtasks, where each step gets Claude's full attention.

### Why Chain Prompts?

| Benefit | Description |
|---------|-------------|
| **Accuracy** | Each subtask gets full attention, reducing errors |
| **Clarity** | Simpler subtasks mean clearer instructions and outputs |
| **Traceability** | Easily pinpoint and fix issues in the chain |

### When to Chain Prompts

Use prompt chaining for:
- **Multi-step tasks** (research synthesis, document analysis)
- **Iterative content creation** (drafting, reviewing, refining)
- Tasks with **multiple transformations**
- Tasks requiring **citations** or **cross-references**

### How to Chain Prompts

1. **Identify subtasks** — Break task into distinct, sequential steps
2. **Structure with XML** — Use XML tags to pass outputs between prompts
3. **Single-task goal** — Each subtask should have one clear objective
4. **Iterate** — Refine subtasks based on performance

### Example Chained Workflows

| Workflow | Steps |
|----------|-------|
| **Content creation** | Research → Outline → Draft → Edit → Format |
| **Data processing** | Extract → Transform → Analyze → Visualize |
| **Decision-making** | Gather info → List options → Analyze each → Recommend |
| **Verification loops** | Generate → Review → Refine → Re-review |

### Debugging Tip

> If Claude misses a step or performs poorly, **isolate that step in its own prompt**. This lets you fine-tune problematic steps without redoing the entire task.

### Optimization Tip

For tasks with **independent subtasks** (like analyzing multiple documents), create separate prompts and **run them in parallel** for speed.

### Advanced: Self-Correction Chains

Chain prompts to have Claude review its own work:

```
Prompt 1: Generate the content
Prompt 2: Review and critique the content
Prompt 3: Refine based on critique
Prompt 4: Final review
```

This catches errors and refines outputs, especially for high-stakes tasks.

---

## 6. Combining Techniques

### Power User Strategy

> **Combine XML tags + Multishot prompting + Chain of thought** to create "super-structured, high-performance prompts."

### Combination Example

```xml
<context>
You are a customer support specialist analyzing feedback.
</context>

<instructions>
For each piece of feedback, classify sentiment and identify issues.
Follow the thinking process shown in examples.
</instructions>

<examples>
  <example>
    <input>"Great product, fast delivery!"</input>
    <thinking>
    Step 1: Identify sentiment words: "great" = positive
    Step 2: Check for issues: none mentioned
    Step 3: Form classification
    </thinking>
    <output>
    <sentiment>positive</sentiment>
    <issue>none</issue>
    </output>
  </example>
  <example>
    <input>"Package arrived damaged. Very disappointed."</input>
    <thinking>
    Step 1: Identify sentiment words: "disappointed" = negative
    Step 2: Check for issues: "package arrived damaged"
    Step 3: Form classification
    </thinking>
    <output>
    <sentiment>negative</sentiment>
    <issue>shipping damage</issue>
    </output>
  </example>
</examples>

<input>{{CUSTOMER_FEEDBACK}}</input>

Please respond using the format shown in examples.
```

### When to Use Each Technique

| Technique | Best For |
|-----------|----------|
| **Be Clear & Direct** | All prompts — foundational practice |
| **Multishot Examples** | Structured outputs, format adherence, patterns |
| **Chain of Thought** | Complex reasoning, math, analysis, problem-solving |
| **XML Tags** | Multi-part prompts, parsing outputs, clarity |
| **Prompt Chaining** | Multi-step workflows, long documents, iterative refinement |

---

## 7. Quick Reference

### Prompt Engineering Checklist

- [ ] Given Claude **context** about purpose, audience, and success criteria
- [ ] Been **specific** about expected output format
- [ ] Provided instructions as **sequential steps**
- [ ] Included **3-5 diverse examples** for pattern-based tasks
- [ ] Used **XML tags** to structure multi-part prompts
- [ ] Added **chain of thought** for complex reasoning tasks
- [ ] Considered **prompt chaining** for multi-step workflows

### Common Pitfalls to Avoid

| Pitfall | Solution |
|---------|----------|
| Vague instructions | Apply the "colleague test" — would someone unfamiliar with the task understand? |
| Missing context | Explicitly state purpose, audience, and success criteria |
| Too few examples | Provide 3-5 diverse examples for pattern-based tasks |
| No structure | Use XML tags to separate instructions, context, and examples |
| Rushing complex tasks | Use prompt chaining to break into subtasks |
| Forgetting CoT | Add "think step-by-step" for complex reasoning |

### Decision Matrix

```
Is the task complex with multiple steps?
├─ Yes → Use Prompt Chaining
└─ No
    ├─ Does it require following a specific format?
    │   ├─ Yes → Use Multishot Examples (3-5)
    │   └─ No → Continue
    ├─ Does it require deep reasoning/analysis?
    │   ├─ Yes → Use Chain of Thought (structured with <thinking> tags)
    │   └─ No → Continue
    └─ Does the prompt have multiple components?
        ├─ Yes → Use XML Tags for structure
        └─ No → Be Clear, Direct, and Detailed
```

---

## Sources

This guide is based on official Anthropic documentation:

- [Be Clear, Direct, and Detailed](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/be-clear-and-direct)
- [Use Examples (Multishot Prompting)](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/multishot-prompting)
- [Let Claude Think (Chain of Thought)](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/chain-of-thought)
- [Use XML Tags](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/use-xml-tags)
- [Chain Complex Prompts](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/chain-prompts)

---

*Last updated: 2025-01-25*
