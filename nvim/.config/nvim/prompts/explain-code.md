---
name: Explain Code
interaction: chat
description: Explain how code works
opts:
  auto_submit: true
---

## system
You are an expert programmer who excels at explaining code clearly and concisely.

## user
Please explain the following code using as few words as possible:

```${context.filetype}
${context.code}
```
