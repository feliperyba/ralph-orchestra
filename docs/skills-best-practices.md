# Skills Best Practices

> Comprehensive reference for creating and using skills in Claude Code and Ralph Orchestra

## What Are Skills?

Skills extend Claude's capabilities through `SKILL.md` files with instructions. Claude uses skills when relevant, or you can invoke them directly with `/skill-name`.

**Key Benefits:**
- Reusable instructions and workflows
- Custom slash commands
- Team knowledge sharing (conventions, patterns, style guides)
- Domain knowledge injection
- Automated workflows with side effects

---

## Quick Start: Create Your First Skill

### Step 1: Create the Skill Directory

```bash
# Personal skill (all projects)
mkdir -p ~/.claude/skills/explain-code

# Project skill (current project only)
mkdir -p .claude/skills/explain-code
```

### Step 2: Write SKILL.md

Every skill needs a `SKILL.md` file with two parts:
1. **YAML frontmatter** (between `---` markers) - tells Claude when to use it
2. **Markdown content** - instructions Claude follows

```markdown
---
name: explain-code
description: Explains code with visual diagrams and analogies. Use when explaining how code works, teaching about a codebase, or when the user asks "how does this work?"
---

When explaining code, always include:

1. **Start with an analogy**: Compare the code to something from everyday life
2. **Draw a diagram**: Use ASCII art to show the flow, structure, or relationships
3. **Walk through the code**: Explain step-by-step what happens
4. **Highlight a gotcha**: What's a common mistake or misconception?

Keep explanations conversational. For complex concepts, use multiple analogies.
```

### Step 3: Test the Skill

```bash
# Let Claude invoke it automatically
How does this code work?

# Or invoke directly
/explain-code src/auth/login.ts
```

---

## Core Principles

### Concise is Key

The context window is a public good. Your Skill shares the context window with everything else Claude needs to know:

- The system prompt
- Conversation history
- Other Skills' metadata
- Your actual request

**Default assumption:** Claude is already very smart. Only add context Claude doesn't already have.

Challenge each piece of information:
- "Does Claude really need this explanation?"
- "Can I assume Claude knows this?"
- "Does this paragraph justify its token cost?"

**Good example (concise, ~50 tokens):**
````markdown
## Extract PDF text

Use pdfplumber for text extraction:

```python
import pdfplumber

with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```
````

**Bad example (too verbose, ~150 tokens):**
````markdown
## Extract PDF text

PDF (Portable Document Format) files are a common file format that contains
text, images, and other content. To extract text from a PDF, you'll need to
use a library. There are many libraries available for PDF processing, but we
recommend pdfplumber because it's easy to use and handles most cases well...
````

### Set Appropriate Degrees of Freedom

Match the level of specificity to the task's fragility and variability.

**High freedom** (text-based instructions) - Use when:
- Multiple approaches are valid
- Decisions depend on context
- Heuristics guide the approach

Example:
```markdown
## Code review process

1. Analyze the code structure and organization
2. Check for potential bugs or edge cases
3. Suggest improvements for readability and maintainability
4. Verify adherence to project conventions
```

**Medium freedom** (pseudocode or scripts with parameters) - Use when:
- A preferred pattern exists
- Some variation is acceptable
- Configuration affects behavior

Example:
```markdown
## Generate report

Use this template and customize as needed:

```python
def generate_report(data, format="markdown", include_charts=True):
    # Process data
    # Generate output in specified format
    # Optionally include visualizations
```
```

**Low freedom** (specific scripts, few or no parameters) - Use when:
- Operations are fragile and error-prone
- Consistency is critical
- A specific sequence must be followed

Example:
```markdown
## Database migration

Run exactly this script:

```bash
python scripts/migrate.py --verify --backup
```

Do not modify the command or add additional flags.
```

**Analogy:** Think of Claude as a robot exploring a path:
- **Narrow bridge with cliffs** (low freedom): One safe way forward - provide specific guardrails
- **Open field** (high freedom): Many paths lead to success - give general direction

### Test with All Models You Plan to Use

Skills act as additions to models, so effectiveness depends on the underlying model.

**Testing considerations by model:**
- **Claude Haiku** (fast, economical): Does the Skill provide enough guidance?
- **Claude Sonnet** (balanced): Is the Skill clear and efficient?
- **Claude Opus** (powerful reasoning): Does the Skill avoid over-explaining?

What works perfectly for Opus might need more detail for Haiku. If you plan to use your Skill across multiple models, aim for instructions that work well with all of them.

---

## Skill Structure

### Directory Structure

Each skill is a directory with `SKILL.md` as the entrypoint:

```
my-skill/
├── SKILL.md           # Main instructions (required)
├── template.md        # Template for Claude to fill in
├── examples/
│   └── sample.md      # Example output showing expected format
└── scripts/
    └── validate.sh    # Script Claude can execute
```

**Best Practice:** Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files.

### Where Skills Live

| Location | Path | Scope | Priority |
|----------|------|-------|----------|
| Enterprise | See managed settings | All users in organization | 1 (highest) |
| Personal | `~/.claude/skills/<skill-name>/SKILL.md` | All your projects | 2 |
| Project | `.claude/skills/<skill-name>/SKILL.md` | This project only | 3 |
| Plugin | `<plugin>/skills/<skill-name>/SKILL.md` | Where plugin enabled | 4 (lowest) |

**Priority:** Higher locations override lower ones when names match. Plugin skills use `plugin-name:skill-name` namespace.

### Automatic Discovery in Nested Directories

When editing files in subdirectories (e.g., `packages/frontend/`), Claude Code automatically discovers skills from nested `.claude/skills/` directories. This supports monorepo setups where packages have their own skills.

### Frontmatter Reference

All fields are optional. Only `description` is recommended.

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Display name. Uses directory name if omitted. Lowercase letters, numbers, hyphens only (max 64 chars). Cannot contain "anthropic" or "claude". |
| `description` | Recommended | What the skill does and when to use it. Claude uses this to decide when to apply the skill. Max 1024 characters, non-empty. |
| `argument-hint` | No | Hint shown during autocomplete. Example: `[issue-number]` or `[filename] [format]`. |
| `disable-model-invocation` | No | Set to `true` to prevent Claude from automatically loading this skill. Default: `false`. |
| `user-invocable` | No | Set to `false` to hide from `/` menu. Default: `true`. |
| `allowed-tools` | No | Tools Claude can use without asking when this skill is active. |
| `model` | No | Model to use when this skill is active (`sonnet`, `opus`, `haiku`). |
| `context` | No | Set to `fork` to run in a subagent context. |
| `agent` | No | Which subagent type to use when `context: fork` is set. |
| `hooks` | No | Hooks scoped to this skill's lifecycle. |
| `category` | No | Category for organization and routing (Ralph Orchestra). |

---

## Naming Conventions

Use consistent naming patterns to make Skills easier to reference and discuss. The official recommendation is **gerund form** (verb + -ing) for Skill names, as this clearly describes the activity or capability the Skill provides.

**Good naming examples (gerund form):**
- `processing-pdfs`
- `analyzing-spreadsheets`
- `managing-databases`
- `testing-code`
- `writing-documentation`

**Acceptable alternatives:**
- Noun phrases: `pdf-processing`, `spreadsheet-analysis`
- Action-oriented: `process-pdfs`, `analyze-spreadsheets`

**Avoid:**
- Vague names: `helper`, `utils`, `tools`
- Overly generic: `documents`, `data`, `files`
- Reserved words: `anthropic-helper`, `claude-tools`

Consistent naming makes it easier to:
- Reference Skills in documentation and conversations
- Understand what a Skill does at a glance
- Organize and search through multiple Skills
- Maintain a professional, cohesive skill library

---

## Writing Effective Descriptions

The `description` field enables Skill discovery and should include both what the Skill does and when to use it.

### Always Write in Third Person

The description is injected into the system prompt, and inconsistent point-of-view can cause discovery problems.

- **Good:** "Processes Excel files and generates reports"
- **Avoid:** "I can help you process Excel files"
- **Avoid:** "You can use this to process Excel files"

### Be Specific and Include Key Terms

Include both what the Skill does and specific triggers/contexts for when to use it.

**Effective examples:**

**PDF Processing skill:**
```yaml
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

**Excel Analysis skill:**
```yaml
description: Analyze Excel spreadsheets, create pivot tables, generate charts. Use when analyzing Excel files, spreadsheets, tabular data, or .xlsx files.
```

**Git Commit Helper skill:**
```yaml
description: Generate descriptive commit messages by analyzing git diffs. Use when the user asks for help writing commit messages or reviewing staged changes.
```

**Avoid vague descriptions like these:**
```yaml
description: Helps with documents    # Too vague
description: Processes data          # Too generic
description: Does stuff with files   # Not useful
```

---

## Progressive Disclosure Patterns

SKILL.md serves as an overview that points Claude to detailed materials as needed, like a table of contents in an onboarding guide.

### Visual Overview: From Simple to Complex

A basic Skill starts with just a SKILL.md file containing metadata and instructions:

```
pdf/
└── SKILL.md    # Metadata + instructions
```

As your Skill grows, bundle additional content that Claude loads only when needed:

```
pdf/
├── SKILL.md              # Main instructions (loaded when triggered)
├── FORMS.md              # Form-filling guide (loaded as needed)
├── REFERENCE.md          # API reference (loaded as needed)
└── EXAMPLES.md           # Usage examples (loaded as needed)
```

### Pattern 1: High-Level Guide with References

```markdown
---
name: pdf-processing
description: Extracts text and tables from PDF files, fills forms, and merges documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
---

# PDF Processing

## Quick start

Extract text with pdfplumber:
```python
import pdfplumber
with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```

## Advanced features

**Form filling**: See [FORMS.md](FORMS.md) for complete guide
**API reference**: See [REFERENCE.md](REFERENCE.md) for all methods
**Examples**: See [EXAMPLES.md](EXAMPLES.md) for common patterns
```

Claude loads FORMS.md, REFERENCE.md, or EXAMPLES.md only when needed.

### Pattern 2: Domain-Specific Organization

For Skills with multiple domains, organize content by domain to avoid loading irrelevant context.

```
bigquery-skill/
├── SKILL.md (overview and navigation)
└── reference/
    ├── finance.md (revenue, billing metrics)
    ├── sales.md (opportunities, pipeline)
    ├── product.md (API usage, features)
    └── marketing.md (campaigns, attribution)
```

SKILL.md:
```markdown
# BigQuery Data Analysis

## Available datasets

**Finance**: Revenue, ARR, billing → See [reference/finance.md](reference/finance.md)
**Sales**: Opportunities, pipeline, accounts → See [reference/sales.md](reference/sales.md)
**Product**: API usage, features, adoption → See [reference/product.md](reference/product.md)
**Marketing**: Campaigns, attribution, email → See [reference/marketing.md](reference/marketing.md)
```

### Pattern 3: Conditional Details

Show basic content, link to advanced content:

```markdown
# DOCX Processing

## Creating documents

Use docx-js for new documents. See [DOCX-JS.md](DOCX-JS.md).

## Editing documents

For simple edits, modify the XML directly.

**For tracked changes**: See [REDLINING.md](REDLINING.md)
**For OOXML details**: See [OOXML.md](OOXML.md)
```

### Avoid Deeply Nested References

Claude may partially read files when referenced from other referenced files. Keep references one level deep from SKILL.md.

**Bad example (too deep):**
```markdown
# SKILL.md
See [advanced.md](advanced.md)...

# advanced.md
See [details.md](details.md)...

# details.md
Here's the actual information...
```

**Good example (one level deep):**
```markdown
# SKILL.md

**Basic usage**: [instructions in SKILL.md]
**Advanced features**: See [advanced.md](advanced.md)
**API reference**: See [reference.md](reference.md)
**Examples**: See [examples.md](examples.md)
```

### Structure Longer Reference Files with Table of Contents

For reference files longer than 100 lines, include a table of contents at the top.

```markdown
# API Reference

## Contents
- Authentication and setup
- Core methods (create, read, update, delete)
- Advanced features (batch operations, webhooks)
- Error handling patterns
- Code examples

## Authentication and setup
...
```

---

## Types of Skill Content

### Reference Content

Adds knowledge Claude applies to current work. Conventions, patterns, style guides.

```markdown
---
name: api-conventions
description: API design patterns for this codebase
---

When writing API endpoints:
- Use RESTful naming conventions
- Return consistent error formats
- Include request validation
```

**Best For:** Team conventions, coding standards, domain knowledge.

### Task Content

Step-by-step instructions for specific actions. Use `disable-model-invocation: true` for manual-only workflows.

```markdown
---
name: deploy
description: Deploy the application to production
context: fork
disable-model-invocation: true
---

Deploy the application:
1. Run the test suite
2. Build the application
3. Push to the deployment target
```

**Best For:** Deployments, commits, code generation - workflows with side effects.

---

## Control Who Invokes a Skill

| Frontmatter | You can invoke | Claude can invoke | When loaded into context |
|-------------|---------------|------------------|-------------------------|
| (default) | Yes | Yes | Description always in context, full skill loads when invoked |
| `disable-model-invocation: true` | Yes | No | Description not in context, full skill loads when you invoke |
| `user-invocable: false` | No | Yes | Description always in context, full skill loads when invoked |

### Use `disable-model-invocation: true` for:

- Workflows with side effects (deploy, commit, send message)
- Timing-sensitive operations you want to control
- Destructive operations

### Use `user-invocable: false` for:

- Background knowledge users shouldn't invoke directly
- Context-only information (e.g., `legacy-system-context`)

---

## Pass Arguments to Skills

Arguments are available via the `$ARGUMENTS` placeholder.

```markdown
---
name: fix-issue
description: Fix a GitHub issue
disable-model-invocation: true
---

Fix GitHub issue $ARGUMENTS following our coding standards.

1. Read the issue description
2. Understand the requirements
3. Implement the fix
4. Write tests
5. Create a commit
```

Usage: `/fix-issue 123`

### String Substitutions

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking the skill |
| `${CLAUDE_SESSION_ID}` | The current session ID (for logging, session-specific files) |

---

## Supporting Files

Reference supporting files from `SKILL.md` so Claude knows what each contains and when to load it.

```markdown
## Additional resources

- For complete API details, see [reference.md](reference.md)
- For usage examples, see [examples.md](examples.md)
```

**Best Practice:** Keep `SKILL.md` focused on essentials. Load reference material only when needed.

---

## Advanced Patterns

### Dynamic Context Injection

The `!`command`` syntax runs shell commands before the skill content is sent to Claude.

```markdown
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
allowed-tools: Bash(gh:*)
---

## Pull request context
- PR diff: !`gh pr diff`
- PR comments: !`gh pr view --comments`
- Changed files: !`gh pr diff --name-only`

## Your task
Summarize this pull request...
```

When invoked:
1. Each `!`command`` executes immediately
2. Output replaces the placeholder
3. Claude receives the fully-rendered prompt with actual data

### Run Skills in a Subagent

Add `context: fork` to run a skill in isolation. The skill content becomes the prompt that drives the subagent.

```markdown
---
name: deep-research
description: Research a topic thoroughly
context: fork
agent: Explore
---

Research $ARGUMENTS thoroughly:

1. Find relevant files using Glob and Grep
2. Read and analyze the code
3. Summarize findings with specific file references
```

**Agent Options:**
- `Explore` - Read-only, optimized for codebase exploration (Haiku)
- `Plan` - Read-only, for planning research
- `general-purpose` - Full tools, capable (default)
- Custom subagents from `.claude/agents/`

### Restrict Tool Access

```markdown
---
name: safe-reader
description: Read files without making changes
allowed-tools: Read, Grep, Glob
---
```

---

## Workflows and Feedback Loops

### Use Workflows for Complex Tasks

Break complex operations into clear, sequential steps. For particularly complex workflows, provide a checklist that Claude can copy into its response and check off as it progresses.

**Example: Research synthesis workflow** (for Skills without code):

```markdown
## Research synthesis workflow

Copy this checklist and track your progress:

```
Research Progress:
- [ ] Step 1: Read all source documents
- [ ] Step 2: Identify key themes
- [ ] Step 3: Cross-reference claims
- [ ] Step 4: Create structured summary
- [ ] Step 5: Verify citations
```

**Step 1: Read all source documents**

Review each document in the `sources/` directory. Note the main arguments and supporting evidence.

**Step 2: Identify key themes**

Look for patterns across sources. What themes appear repeatedly? Where do sources agree or disagree?

**Step 3: Cross-reference claims**

For each major claim, verify it appears in the source material. Note which source supports each point.

**Step 4: Create structured summary**

Organize findings by theme. Include:
- Main claim
- Supporting evidence from sources
- Conflicting viewpoints (if any)

**Step 5: Verify citations**

Check that every claim references the correct source document.
```

### Implement Feedback Loops

**Common pattern:** Run validator → fix errors → repeat

This pattern greatly improves output quality.

**Example: Document editing process** (for Skills with code):

```markdown
## Document editing process

1. Make your edits to `word/document.xml`
2. **Validate immediately**: `python ooxml/scripts/validate.py unpacked_dir/`
3. If validation fails:
   - Review the error message carefully
   - Fix the issues in the XML
   - Run validation again
4. **Only proceed when validation passes**
5. Rebuild: `python ooxml/scripts/pack.py unpacked_dir/ output.docx`
6. Test the output document
```

The validation loop catches errors early.

---

## Content Guidelines

### Avoid Time-Sensitive Information

Don't include information that will become outdated.

**Bad example (time-sensitive):**
```markdown
If you're doing this before August 2025, use the old API.
After August 2025, use the new API.
```

**Good example (use "old patterns" section):**
```markdown
## Current method

Use the v2 API endpoint: `api.example.com/v2/messages`

## Old patterns

<details>
<summary>Legacy v1 API (deprecated 2025-08)</summary>

The v1 API used: `api.example.com/v1/messages`

This endpoint is no longer supported.
</details>
```

### Use Consistent Terminology

Choose one term and use it throughout the Skill:

**Good - Consistent:**
- Always "API endpoint"
- Always "field"
- Always "extract"

**Bad - Inconsistent:**
- Mix "API endpoint", "URL", "API route", "path"
- Mix "field", "box", "element", "control"
- Mix "extract", "pull", "get", "retrieve"

---

## Common Patterns

### Template Pattern

Provide templates for output format. Match the level of strictness to your needs.

**For strict requirements** (like API responses or data formats):

```markdown
## Report structure

ALWAYS use this exact template structure:

```markdown
# [Analysis Title]

## Executive summary
[One-paragraph overview of key findings]

## Key findings
- Finding 1 with supporting data
- Finding 2 with supporting data
- Finding 3 with supporting data

## Recommendations
1. Specific actionable recommendation
2. Specific actionable recommendation
```
```

**For flexible guidance** (when adaptation is useful):

```markdown
## Report structure

Here is a sensible default format, but use your best judgment based on the analysis:

```markdown
# [Analysis Title]

## Executive summary
[Overview]

## Key findings
[Adapt sections based on what you discover]

## Recommendations
[Tailor to the specific context]
```

Adjust sections as needed for the specific analysis type.
```

### Examples Pattern

For Skills where output quality depends on seeing examples, provide input/output pairs:

```markdown
## Commit message format

Generate commit messages following these examples:

**Example 1:**
Input: Added user authentication with JWT tokens
Output:
```
feat(auth): implement JWT-based authentication

Add login endpoint and token validation middleware
```

**Example 2:**
Input: Fixed bug where dates displayed incorrectly in reports
Output:
```
fix(reports): correct date formatting in timezone conversion

Use UTC timestamps consistently across report generation
```

Follow this style: type(scope): brief description, then detailed explanation.
```

### Conditional Workflow Pattern

Guide Claude through decision points:

```markdown
## Document modification workflow

1. Determine the modification type:

   **Creating new content?** → Follow "Creation workflow" below
   **Editing existing content?** → Follow "Editing workflow" below

2. Creation workflow:
   - Use docx-js library
   - Build document from scratch
   - Export to .docx format

3. Editing workflow:
   - Unpack existing document
   - Modify XML directly
   - Validate after each change
   - Repack when complete
```

---

## Evaluation and Iteration

### Build Evaluations First

**Create evaluations BEFORE writing extensive documentation.** This ensures your Skill solves real problems rather than documenting imagined ones.

**Evaluation-driven development:**
1. **Identify gaps**: Run Claude on representative tasks without a Skill. Document specific failures or missing context
2. **Create evaluations**: Build three scenarios that test these gaps
3. **Establish baseline**: Measure Claude's performance without the Skill
4. **Write minimal instructions**: Create just enough content to address the gaps and pass evaluations
5. **Iterate**: Execute evaluations, compare against baseline, and refine

**Evaluation structure:**
```json
{
  "skills": ["pdf-processing"],
  "query": "Extract all text from this PDF file and save it to output.txt",
  "files": ["test-files/document.pdf"],
  "expected_behavior": [
    "Successfully reads the PDF file using an appropriate PDF processing library or command-line tool",
    "Extracts text content from all pages in the document without missing any pages",
    "Saves the extracted text to a file named output.txt in a clear, readable format"
  ]
}
```

### Develop Skills Iteratively with Claude

The most effective Skill development process involves Claude itself. Work with one instance of Claude ("Claude A") to create a Skill that will be used by other instances ("Claude B").

**Creating a new Skill:**
1. **Complete a task without a Skill**: Work through a problem with Claude A using normal prompting. Notice what information you repeatedly provide.
2. **Identify the reusable pattern**: What context would be useful for similar future tasks?
3. **Ask Claude A to create a Skill**: "Create a Skill that captures this pattern we just used."
4. **Review for conciseness**: Check that Claude A hasn't added unnecessary explanations.

**Iterating on existing Skills:**
1. **Use the Skill in real workflows**: Give Claude B actual tasks, not test scenarios
2. **Observe Claude B's behavior**: Note where it struggles, succeeds, or makes unexpected choices
3. **Return to Claude A for improvements**: Share what you observed and ask for refinements
4. **Apply and test changes**: Update the Skill, then test again with Claude B

### Observe How Claude Navigates Skills

As you iterate, pay attention to how Claude actually uses skills:
- **Unexpected exploration paths**: Does Claude read files in an order you didn't anticipate?
- **Missed connections**: Does Claude fail to follow references to important files?
- **Overreliance on certain sections**: If Claude repeatedly reads the same file, consider moving that content to SKILL.md
- **Ignored content**: If Claude never accesses a bundled file, it might be unnecessary

---

## Anti-Patterns to Avoid

### Avoid Windows-Style Paths

Always use forward slashes in file paths, even on Windows:

- ✓ **Good**: `scripts/helper.py`, `reference/guide.md`
- ✗ **Avoid**: `scripts\helper.py`, `reference\guide.md`

Unix-style paths work across all platforms.

### Avoid Offering Too Many Options

Don't present multiple approaches unless necessary:

**Bad example (too many choices):**
```markdown
You can use pypdf, or pdfplumber, or PyMuPDF, or pdf2image, or...
```

**Good example (provide default with escape hatch):**
```markdown
Use pdfplumber for text extraction:

```python
import pdfplumber
```

For scanned PDFs requiring OCR, use pdf2image with pytesseract instead.
```

### Avoid Assuming Tools Are Installed

Don't assume packages are available:

**Bad example:**
```markdown
Use the pdf library to process the file.
```

**Good example:**
```markdown
Install required package: `pip install pypdf`

Then use it:
```python
from pypdf import PdfReader
reader = PdfReader("file.pdf")
```
```

---

## Advanced: Skills with Executable Code

### Solve, Don't Punt

When writing scripts for Skills, handle error conditions rather than punting to Claude.

**Good example (handle errors explicitly):**
```python
def process_file(path):
    """Process a file, creating it if it doesn't exist."""
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        # Create file with default content instead of failing
        print(f"File {path} not found, creating default")
        with open(path, 'w') as f:
            f.write('')
        return ''
    except PermissionError:
        # Provide alternative instead of failing
        print(f"Cannot access {path}, using default")
        return ''
```

**Bad example (punt to Claude):**
```python
def process_file(path):
    # Just fail and let Claude figure it out
    return open(path).read()
```

### Provide Utility Scripts

Even if Claude could write a script, pre-made scripts offer advantages:

**Benefits of utility scripts:**
- More reliable than generated code
- Save tokens (no need to include code in context)
- Save time (no code generation required)
- Ensure consistency across uses

**Make execution intent clear:**
- **Execute** (most common): "Run `analyze_form.py` to extract fields"
- **Read as reference** (for complex logic): "See `analyze_form.py` for the extraction algorithm"

### Create Verifiable Intermediate Outputs

The "plan-validate-execute" pattern catches errors early by having Claude first create a plan in a structured format, then validate that plan with a script before executing it.

**When to use:**
- Batch operations
- Destructive changes
- Complex validation rules
- High-stakes operations

### Package Dependencies

Skills run in the code execution environment with platform-specific limitations:

- **claude.ai**: Can install packages from npm and PyPI
- **Anthropic API**: Has no network access and no runtime package installation

List required packages in your SKILL.md and verify they're available.

### MCP Tool References

If your Skill uses MCP (Model Context Protocol) tools, always use fully qualified tool names.

**Format:** `ServerName:tool_name`

**Example:**
```markdown
Use the BigQuery:bigquery_schema tool to retrieve table schemas.
Use the GitHub:create_issue tool to create issues.
```

Where:
- `BigQuery` and `GitHub` are MCP server names
- `bigquery_schema` and `create_issue` are the tool names within those servers

---

## Restrict Claude's Skill Access

Control which skills Claude can invoke automatically.

### Disable All Skills

```json
// Add to deny rules in /permissions
Skill
```

### Allow or Deny Specific Skills

```json
// Allow only specific skills
Skill(commit)
Skill(review-pr:*)

// Deny specific skills
Skill(deploy:*)
```

**Syntax:** `Skill(name)` for exact match, `Skill(name:*)` for prefix match.

### Hide Individual Skills

Add `disable-model-invocation: true` to frontmatter. This removes the skill from Claude's context entirely.

**Note:** `user-invocable` only controls menu visibility, not Skill tool access. Use `disable-model-invocation: true` to block programmatic invocation.

---

## Troubleshooting

### Skill Not Triggering

1. Check description includes keywords users would naturally say
2. Verify skill appears in `What skills are available?`
3. Try rephrasing request to match description
4. Invoke directly with `/skill-name`

### Skill Triggers Too Often

1. Make description more specific
2. Add `disable-model-invocation: true` for manual-only use

### Claude Doesn't See All Skills

Skill descriptions are loaded into context. If you have many skills, they may exceed the character budget (default: 15,000 characters).

**Solution:** Run `/context` to check for warnings. Increase limit with:
```bash
export SLASH_COMMAND_TOOL_CHAR_BUDGET=30000
```

---

## Complete Examples

### Code Reviewer Skill

```markdown
---
name: code-reviewer
description: Expert code reviewer. Use proactively after code changes for quality, security, and maintainability feedback.
---

You are a senior code reviewer. When invoked:

1. Run git diff to see recent changes
2. Focus on modified files
3. Begin review immediately

Review checklist:
- Code is clear and readable
- Functions and variables are well-named
- No duplicated code
- Proper error handling
- No exposed secrets or API keys
- Input validation implemented
- Good test coverage
- Performance considerations addressed

Provide feedback organized by priority:
- Critical issues (must fix)
- Warnings (should fix)
- Suggestions (consider improving)

Include specific examples of how to fix issues.
```

### Deploy Skill (Manual Only)

```markdown
---
name: deploy
description: Deploy the application to production
disable-model-invocation: true
argument-hint: [environment]
---

Deploy $ARGUMENTS to production:

1. Run the test suite: `npm test`
2. Build the application: `npm run build`
3. Push to deployment target
4. Verify the deployment succeeded
5. Run smoke tests
```

### API Conventions Reference

```markdown
---
name: api-conventions
description: API design patterns and conventions for this codebase. Use when designing or implementing API endpoints.
---

## API Design Conventions

### RESTful Naming

- Use plural nouns for collections: `/users`, `/posts`
- Use kebab-case for resource IDs: `/users/123`
- Nest resources logically: `/users/123/posts/456`

### Response Format

Success:
```json
{
  "data": { ... },
  "meta": { "page": 1, "perPage": 20 }
}
```

Error:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": { ... }
  }
}
```

See [api-reference.md](api-reference.md) for complete endpoint documentation.
```

---

## Commands vs Skills

**Historical Note:** Custom slash commands (`.claude/commands/`) have been merged into skills. Both work the same way now.

| Aspect | Commands | Skills |
|--------|----------|--------|
| Location | `.claude/commands/review.md` | `.claude/skills/review/SKILL.md` |
| Slash command | `/review` | `/review` |
| Supporting files | No | Yes (directory structure) |
| Frontmatter | Yes | Yes (with additional fields) |
| Priority | Lower | Higher (skills take precedence) |

**Recommendation:** Use skills for new work. Existing command files keep working.

---

## Checklist for Effective Skills

Before sharing a Skill, verify:

### Core Quality

- [ ] Description is specific and includes key terms
- [ ] Description includes both what the Skill does and when to use it
- [ ] Description is written in third person
- [ ] SKILL.md body is under 500 lines
- [ ] Additional details are in separate files (if needed)
- [ ] No time-sensitive information (or in "old patterns" section)
- [ ] Consistent terminology throughout
- [ ] Examples are concrete, not abstract
- [ ] File references are one level deep
- [ ] Progressive disclosure used appropriately
- [ ] Workflows have clear steps

### Code and Scripts

- [ ] Scripts solve problems rather than punt to Claude
- [ ] Error handling is explicit and helpful
- [ ] No "voodoo constants" (all values justified)
- [ ] Required packages listed in instructions and verified as available
- [ ] Scripts have clear documentation
- [ ] No Windows-style paths (all forward slashes)
- [ ] Validation/verification steps for critical operations
- [ ] Feedback loops included for quality-critical tasks

### Testing

- [ ] At least three evaluations created
- [ ] Tested with Haiku, Sonnet, and Opus (if using multiple models)
- [ ] Tested with real usage scenarios
- [ ] Team feedback incorporated (if applicable)

---

## References

- [Official Claude Agent Skills Documentation](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Claude Code Subagents Documentation](https://code.claude.com/docs/en/sub-agents)
- [Ralph Orchestra Architecture](./architecture.md)
- [Subagent Best Practices](./subagent-best-practices.md)
