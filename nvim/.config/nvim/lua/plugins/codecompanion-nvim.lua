return {
  "olimorris/codecompanion.nvim",
  version = "^19.0.0",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    -- completion
    "hrsh7th/nvim-cmp",
    -- optional progress indicator
    "j-hui/fidget.nvim",
    -- optional MCP support
    "ravitemer/mcphub.nvim",
    -- optional markdown support
    -- {
    --   "MeanderingProgrammer/render-markdown.nvim",
    --   ft = { "codecompanion" },
    -- },
  },
  cmd = {
    "CodeCompanion",
    "CodeCompanionChat",
    "CodeCompanionActions",
  },
  opts = {
    adapters = {
      http = {
        openai = function()
          return require("codecompanion.adapters").extend("openai", {
            env = {
              api_key = "cmd:secret-tool lookup openai neovim",
            },
          })
        end,
      },
    },
    display = {
      chat = {
        show_token_count = true,
        show_settings = true,
        window = {
          width = 0.4,
        },
      },
      action_palette = {
        opts = {
          title = "CodeCompanion Actions",
          show_prompt_library_builtins = false,
          show_preset_actions = false,
          show_preset_prompts = false,
          show_preset_rules = false,
        }
      },
    },
    interactions = {
      inline = {
        adapter = "openai",
        model = "gpt4.1",
      },
      chat = {
        adapter = "openai",
        model = "gpt4.1",
        opts = {
          completion_provider = "cmp", -- blink|cmp|coc|default
          system_prompt = [[
            You are an AI programming assistant named "CodeCompanion", working within the Neovim text editor.
            The user really loves concise answers, so don't be even slightly verbose.

            You can answer general programming questions and perform the following tasks:
            * Answer general programming questions.
            * Explain how the code in a Neovim buffer works.
            * Review the selected code from a Neovim buffer.
            * Generate unit tests for the selected code.
            * Propose fixes for problems in the selected code.
            * Scaffold code for a new workspace.
            * Find relevant code to the user's query.
            * Propose fixes for test failures.

            Follow the user's requirements carefully and to the letter.
            Use the context and attachments the user provides.
            Keep your answers extremely short and impersonal.
            Use Markdown formatting in your answers.
            Do not use H1 or H2 markdown headers.
            When suggesting code changes or new content, use Markdown code blocks.
            To start a code block, use 4 backticks.
            After the backticks, add the programming language name as the language ID.
            To close a code block, use 4 backticks on a new line.
            If the code modifies an existing file or should be placed at a specific location, add a line comment with 'filepath:' and the file path.
            If you want the user to decide where to place the code, do not add the file path comment.
            In the code block, use a line comment with '...existing code...' to indicate code that is already present in the file.
            Code block example:
            ````languageId
            // filepath: /path/to/file
            // ...existing code...
            { changed code }
            // ...existing code...
            { changed code }
            // ...existing code...
            ````
            Ensure line comments use the correct syntax for the programming language (e.g. "#" for Python, "--" for Lua).
            For code blocks use four backticks to start and end.
            Avoid wrapping the whole response in triple backticks.
            Do not include diff formatting unless explicitly asked.
            Do not include line numbers in code blocks.

            When given a task:
            1. Think step-by-step.
            2. When outputting code blocks, ensure only relevant code is included, avoiding any repeating or unrelated code.
            3. Any non-code portion of your response should use as few words as possible. Only include detail if absolutely necessary!
            4. Only if you need more information, end your response with a question that would provide you the information you need to continue.
            5. The response must ALWAYS be in English.

            Additional context:
            All non-code text responses must be written in the ${language} language.
            The current date is ${date}.
            The user's Neovim version is ${version}.
            The user is working on a ${os} machine. Please respond with system specific commands if applicable.
          ]],
        },
        -- This fixes a bug where mcphub expects this table to be non-null
        variables = {}
      },
      shared = {
        keymaps = {
          accept_change = {
            callback = "keymaps.accept_change",
            description = "Accept change",
            index = 1,
            modes = { n = "<leader>ca" },
            opts = { nowait = true, noremap = true },
          },
          reject_change = {
            callback = "keymaps.reject_change",
            description = "Reject change",
            index = 2,
            modes = { n = "<leader>cr" },
            opts = { nowait = true, noremap = true },
          },
          always_accept = {
            callback = "keymaps.always_accept",
            description = "Always accept changes in this buffer",
            index = 3,
            modes = { n = "<leader>cA" },
            opts = { nowait = true },
          },
          next_hunk = {
            callback = "keymaps.next_hunk",
            description = "Go to next hunk",
            modes = { n = "<leader>cn" },
          },
          previous_hunk = {
            callback = "keymaps.previous_hunk",
            description = "Go to previous hunk",
            modes = { n = "<leader>cp" },
          },
        },
      },
    },
    prompt_library = {
      markdown = {
        dirs = {
          "~/.config/nvim/prompts",
        },
      },
    },
    extensions = {
      mcphub = {
        callback = "mcphub.extensions.codecompanion",
        opts = {
          make_tools = true,                    -- Make individual tools (@server__tool) and server groups (@server) from MCP servers
          make_slash_commands = true,           -- Add MCP prompts as /slash commands
          make_vars = true,                     -- Convert MCP resources to #variables for prompts
          show_server_tools_in_chat = true,     -- Show individual tools in chat completion (when make_tools=true)
          show_result_in_chat = true,           -- Show tool results directly in chat buffer
          add_mcp_prefix_to_tool_names = false, -- Add mcp__ prefix (e.g `@mcp__github`, `@mcp__neovim__list_issues`)
        }
      }
    }
  },
  config = function(_, opts)
    require('codecompanion').setup(opts)
    require('custom.codecompanion.fidget-spinner'):init()
  end,
}
