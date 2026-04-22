````md
---
name: apply-sky-formatting
description: This document defines **exact, mechanical formatting rules** for MakerDAO-style Solidity used across the ecosystem (example: `PSM3.sol`). The key requirement is **visual alignment**: identifiers, `=`, commas, parentheses, and certain operator blocks are aligned **even when it requires extra whitespace**.
---

This document defines **exact, mechanical formatting rules** for MakerDAO-style Solidity used across the ecosystem (example: `PSM3.sol`). The key requirement is **visual alignment**: identifiers, `=`, commas, parentheses, and certain operator blocks are aligned **even when it requires extra whitespace**.

An agent applying this skill must prioritize:
1. **Readability by column alignment**
2. **Consistency within a file**
3. **Minimal semantic change (format-only)**

## 0) Non-goals

- Do not change logic.
- Do not rename variables.
- Do not change conditional statements or control flow.
- Do not reorder code unless explicitly described here (imports can be grouped/ordered; see below).
- Do not “optimize” formatting away (e.g., by running a formatter that removes alignment).

---

## 1) High-level layout conventions

### 1.1 SPDX, pragma, imports, contract header

- SPDX on first line.
- Blank line after SPDX.
- `pragma` next.
- Blank line after `pragma`.
- Imports grouped with **blank lines** between logical groups.

**Example**

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { Math }    from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import { IPSM3 }             from "src/interfaces/IPSM3.sol";
import { IRateProviderLike } from "src/interfaces/IRateProviderLike.sol";
````

---

## 2) Alignment rules (core of the skill)

### 2.1 Import alignment

When importing multiple symbols, align `{ ... }` contents and/or spacing so names line up in a readable column.

**Rule**

* If multiple `import { X }` lines appear adjacent and the symbol names have different lengths, pad spaces so symbol names align in a column.

**Example**

```solidity
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { Math }    from "openzeppelin-contracts/contracts/utils/math/Math.sol";
```

**Also acceptable** (when importing multiple symbols per line, align within braces):

```solidity
import { Foo,      Bar } from "src/FooBar.sol";
import { LongName, Baz } from "src/LongBaz.sol";
```

---

### 2.2 State variable declarations

#### 2.2.1 Type / visibility / modifiers / name alignment

Align declarations by inserting spaces so names form neat columns when grouped.

**Preferred patterns**

* Align `public override immutable` blocks vertically.
* Align variable names in a column when multiple declarations are adjacent.

**Example**

```solidity
IERC20 public override immutable usdc;
IERC20 public override immutable usds;
IERC20 public override immutable susds;

address public override immutable rateProvider;

address public override pocket;

uint256 public override totalShares;

mapping(address user => uint256 shares) public override shares;
```

If a group mixes different types, align the **names** column when it improves readability, but do not force alignment that makes lines unreadable. Maker style tends to align in small logical groups (like the example above).

---

### 2.3 Assignments: align equals signs (`=`) within a block

This is one of the most visible Maker conventions.

**Rule**

* In an adjacent assignment block, pad spaces so the `=` signs line up vertically.
* This applies to local variables, state variables, constructor assignments, etc.

**Example**

```solidity
usdc  = IERC20(usdc_);
usds  = IERC20(usds_);
susds = IERC20(susds_);

rateProvider = rateProvider_;
pocket       = address(this);
```

**Example with locals**

```solidity
address pocket_          = pocket;
uint256 amountToTransfer = usdc.balanceOf(pocket_);
```

---

### 2.4 Multi-line function signatures: one parameter per line, aligned

**Rule**

* For “long” signatures, put each parameter on its own line.
* Indent parameters consistently (one level deeper than `function ...(` line).
* Closing `)` aligns under `function` indentation level.
* Place `external override returns (...)` on the signature line when it fits; otherwise, break before `external` or `returns` consistently with file style.

**Example**

```solidity
function swapExactIn(
    address assetIn,
    address assetOut,
    uint256 amountIn,
    uint256 minAmountOut,
    address receiver,
    uint256 referralCode
)
    external override returns (uint256 amountOut)
{
    ...
}
```

---

### 2.5 Constructor formatting

**Rule**

* Multi-arg constructors use the same “one per line” parameter style.
* Base constructor invocation is on its own line, aligned with the constructor indentation.
* Opening `{` on its own line after base constructor call block.

**Example**

```solidity
constructor(
    address owner_,
    address usdc_,
    address usds_,
    address susds_,
    address rateProvider_
)
    Ownable(owner_)
{
    ...
}
```

---

### 2.6 Require alignment (especially multi-require sequences)

**Rule**

* When multiple `require(...)` calls appear in a series, align arguments visually:

  * Align the expression portions (by padding after identifiers) when they share a pattern.
  * Align the error strings as a column where practical.

**Example**

```solidity
require(usdc_         != address(0), "PSM3/invalid-usdc");
require(usds_         != address(0), "PSM3/invalid-usds");
require(susds_        != address(0), "PSM3/invalid-susds");
require(rateProvider_ != address(0), "PSM3/invalid-rateProvider");
```

**Example (pairwise comparisons)**

```solidity
require(usdc_ != usds_,  "PSM3/usdc-usds-same");
require(usdc_ != susds_, "PSM3/usdc-susds-same");
require(usds_ != susds_, "PSM3/usds-susds-same");
```

Note the deliberate double-space after comma in the first line to keep strings aligned.

---

### 2.7 Conditional chains: align `if / else if` and returns

**Rule**

* For short `if/else if` chains returning values, align the `return` statements and/or the conditions when it improves scanning.
* Maker style frequently uses:

```solidity
if      (cond1) return ...
else if (cond2) return ...
return ...
```

**Example**

```solidity
if      (asset == address(usdc)) return assetValue * _usdcPrecision / 1e18;
else if (asset == address(usds)) return assetValue * _usdsPrecision / 1e18;

return assetValue
    * 1e9
    * _susdsPrecision
    / IRateProviderLike(rateProvider).getConversionRate();
```

Note:

* The `if` keyword is padded: `if      (` and `else if (`.
* Blank line before the final `return` for readability.

---

### 2.8 Ternary formatting: align `?` and `:` blocks when multiline

**Rule**

* For multiline ternaries, put `?` and `:` aligned and indent the branches.

**Example**

```solidity
assetsWithdrawn = assetBalance < maxAssetsToWithdraw
    ? assetBalance
    : maxAssetsToWithdraw;
```

---

### 2.9 Tuple assignment spacing: spaces inside parentheses

**Rule**

* When destructuring tuples, include spaces just inside the parentheses.
* Align multi-variable tuple assignment for readability.

**Example**

```solidity
( sharesToBurn, assetsWithdrawn ) = previewWithdraw(asset, maxAssetsToWithdraw);
```

---

### 2.10 Function calls with inline comments: keep comment column consistent

**Rule**

* Inline end-of-line comments (e.g., `// Round down`) should be aligned within a local block where possible.

**Example**

```solidity
return convertToShares(getAssetValue(asset, assetsToDeposit, false));  // Round down
```

If multiple similar lines exist, align the `//` columns:

```solidity
amountOut = _getSwapQuote(assetIn,  assetOut, amountIn,  false);  // Round down
amountIn  = _getSwapQuote(assetOut, assetIn,  amountOut, true );  // Round up
```

(Do not introduce trailing spaces; adjust internal spacing instead.)

---

### 2.11 Arithmetic formatting: line breaks + operator alignment

**Rule**

* For long arithmetic expressions, break across lines with operators leading the continuation line or grouped consistently.
* Maker style in PSM3 uses a *visual stacking* pattern with `+` aligned.

**Example**

```solidity
return _getUsdcValue(usdc.balanceOf(pocket))
    +  _getUsdsValue(usds.balanceOf(address(this)))
    +  _getSUsdsValue(susds.balanceOf(address(this)), false);  // Round down
```

Note:

* `+` is aligned and spaced as `+  ` (plus, two spaces) to visually line up the function calls.
* Continuation lines are indented one level.

---

### 2.12 Multiline returns: align `return` continuation indentation

**Rule**

* When returning a multiline expression, place `return` on its own line or with the first term, then indent continuation lines consistently.

**Example**

```solidity
return assetValue
    * 1e9
    * _susdsPrecision
    / IRateProviderLike(rateProvider).getConversionRate();
```

---

## 3) Comment block conventions (section headers)

Maker contracts often use heavy section banners.

**Rule**

* Section blocks use a fixed-width `/**********************************************************************************************/`
* A title line with `/*** ... ***/` centered-ish by spacing.
* Same closing banner line.
* Use these to break up major feature sets.

**Example**

```solidity
/**********************************************************************************************/
/*** Owner functions                                                                        ***/
/**********************************************************************************************/
```

**Agent requirement**

* Do not change banner widths.
* Preserve the alignment of the section title line (spaces are meaningful).

---

## 4) Spacing rules (micro-style)

### 4.1 No tabs

* Use spaces only.

### 4.2 No trailing whitespace

* Alignment may add whitespace **inside** lines but never trailing at end-of-line.

### 4.3 Blank lines

* Use blank lines to separate logical units:

  * import groups
  * state variable groups
  * major function groups (often already separated by banners)
  * within a function: between require/compute/pull/push blocks

---

## 5) “Before → After” transformations (common fixes)

### 5.1 Assignment alignment

**Before**

```solidity
usdc = IERC20(usdc_);
usds = IERC20(usds_);
susds = IERC20(susds_);
pocket = address(this);
```

**After**

```solidity
usdc  = IERC20(usdc_);
usds  = IERC20(usds_);
susds = IERC20(susds_);

pocket = address(this);
```

If `pocket` is conceptually tied to `rateProvider`, align together:

```solidity
rateProvider = rateProvider_;
pocket       = address(this);
```

---

### 5.2 Require alignment

**Before**

```solidity
require(usdc_ != address(0), "PSM3/invalid-usdc");
require(usds_ != address(0), "PSM3/invalid-usds");
require(susds_ != address(0), "PSM3/invalid-susds");
```

**After**

```solidity
require(usdc_  != address(0), "PSM3/invalid-usdc");
require(usds_  != address(0), "PSM3/invalid-usds");
require(susds_ != address(0), "PSM3/invalid-susds");
```

---

### 5.3 `if / else if` chain alignment

**Before**

```solidity
if (asset == address(usdc)) return a;
else if (asset == address(usds)) return b;
else return c;
```

**After**

```solidity
if      (asset == address(usdc)) return a;
else if (asset == address(usds)) return b;

return c;
```

---

### 5.4 Ternary formatting

**Before**

```solidity
x = cond ? a : b;
```

**After**

```solidity
x = cond
    ? a
    : b;
```

(Use multiline if the condition or branches are non-trivial or if it improves local readability.)

---

### 5.5 Multiline arithmetic stacking

**Before**

```solidity
return f(a) + g(b) + h(c, false);
```

**After**

```solidity
return f(a)
    +  g(b)
    +  h(c, false);
```

---

## 6) Applying the skill: deterministic procedure

When editing a file:

1. **Identify alignment blocks**:

   * consecutive imports
   * consecutive state variable declarations
   * consecutive `require(...)` statements
   * consecutive assignments
   * arithmetic “sum stacks”
   * if/else if return chains

2. **Compute max column positions** per block:

   * For assignments: position of `=`
   * For require blocks: align the start of the string literal where possible
   * For import blocks: align symbol names or brace contents
   * For stacked arithmetic: align operators (`+`, sometimes `-`) with consistent spacing

3. **Insert internal whitespace** only:

   * Add spaces between tokens, not within identifiers.
   * Never add trailing whitespace.

4. **Preserve semantic grouping**:

   * Do not align across unrelated blocks; alignment resets at blank lines and section banners.

5. **Re-check “Maker look”**:

   * Does the result resemble `PSM3.sol` section by section?
   * Are columns straight within each block?

---

## 7) Validation checklist

* [ ] SPDX + pragma + import grouping matches pattern
* [ ] Import symbol names aligned within local import blocks
* [ ] State variable groups are visually aligned (especially `immutable` groups)
* [ ] Adjacent assignments have aligned `=`
* [ ] Multi-`require` blocks aligned (both condition padding and string column where used)
* [ ] Multi-line function signatures are one-parameter-per-line
* [ ] `if      (...)` / `else if (...)` alignment used for return chains
* [ ] Multiline ternaries formatted with aligned `?` / `:`
* [ ] Tuple destructuring uses `( a, b )` spacing
* [ ] Arithmetic stacks use aligned operators (`+  `) when in a list
* [ ] No tabs; no trailing whitespace
* [ ] No logic changes, no reordered behavior

---

## 8) Additional examples (copy/paste templates)

### 8.1 Standard section header

```solidity
/**********************************************************************************************/
/*** Title                                                                                ***/
/**********************************************************************************************/
```

### 8.2 Standard “preview” function style

```solidity
function previewSwapExactIn(address assetIn, address assetOut, uint256 amountIn)
    public view override returns (uint256 amountOut)
{
    // Round down to get amountOut
    amountOut = _getSwapQuote(assetIn, assetOut, amountIn, false);
}
```

### 8.3 “Round up” helper with `Math.ceilDiv`

```solidity
return Math.ceilDiv(
    Math.ceilDiv(amount * IRateProviderLike(rateProvider).getConversionRate(), 1e9),
    _susdsPrecision
);
```

### 8.4 “Convert one-to-one” helper with aligned args

```solidity
function _convertOneToOne(
    uint256 amount,
    uint256 assetPrecision,
    uint256 convertAssetPrecision,
    bool roundUp
)
    internal pure returns (uint256)
{
    if (!roundUp) return amount * convertAssetPrecision / assetPrecision;

    return Math.ceilDiv(amount * convertAssetPrecision, assetPrecision);
}
```

---

## 9) Agent operating constraints

* Do not run a formatter that will undo alignment (e.g., a standard `forge fmt` pass) unless it is configured to preserve these conventions.
* Prefer localized edits: align within the smallest sensible block.
* When unsure whether to align, follow the precedent in the nearest surrounding code: **PSM3-style alignment wins**.

---


