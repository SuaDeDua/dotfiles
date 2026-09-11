---
name: Write PR Description
interaction: chat
description: Write a nice PR description using the latest commit in this repo
opts:
  auto_submit: true
---

## user

You are an expert developer with good documentation habits.  Given the diff listed below, write an accurate Pull Request message using as few words as possible:

```diff
${latest-commit.diff}
```
