# Sweeping a tree for British spellings

Companion to `writing.md`'s *Use American spellings*, which carries the directive. Load this before
searching a tree for British spellings to fix.

## A stem match overreaches

A stem match hits words that are already American — `organis` catches `organism`, `generalis`
catches `generalist`, `enrol` catches `enrollment`, `realis` catches `realistic`. A quoted passage
keeps its source's spelling, so an external quote is not yours to correct. And `analyses` is the
noun plural in both, so changing it fixes no spelling and can break an anchor link into a heading
that uses it.

## A word list bounds the absence claim

A hand-built word list bounds an absence claim to the list rather than to the corpus, and that
false-negative direction is worse than the stem-match overreach above: an overreach produces a wrong
edit somebody catches, where a missed word produces a clean report nobody rechecks — `catalogue`
survives a sweep built around `colour` and `behaviour`. So report what was searched, "these are the
hits for this list", rather than "everything else is clean". That is `honesty.md`'s *Do Not Assert
Absence Without Verifying* in the term-search form that file already describes.
