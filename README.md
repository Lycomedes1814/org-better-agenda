# Org-Better-Agenda

Emacs package providing a custom `org-agenda` view with opinionated sorting and highlighting.

## Features

- **30-day agenda** starting today, with all-day events sorted before timed entries
- **"Must do" section** — overdue deadlines and deadlines within the next 60 days, sorted by earliest date
- **"When I have time" section** — tasks without any date
- Custom faces for timed entries, all-day events, deadline dates, and scheduled dates
- Integrates with `org-modern` for styling
- **Multilingual** — English, Norwegian, Italian, and German built in
- Optional recommended config with capture templates, keybindings, and Everforest-style colors

## Requirements

- Emacs 28+
- [org-mode](https://orgmode.org/)
- [org-modern](https://github.com/minad/org-modern)

## Installation

### Manual

Clone the repo and add it to your load path:

```emacs-lisp
(add-to-list 'load-path "/path/to/org-better-agenda")
(require 'org-better-agenda)
```

### use-package

```emacs-lisp
(use-package org-better-agenda
  :load-path "/path/to/org-better-agenda")
```

## Usage

```
M-x org-better-agenda
```

Or bind it to a key:

```emacs-lisp
(global-set-key (kbd "C-c a") #'org-better-agenda)
```

## Language

Set `org-better-agenda-language` before loading the package (or call
`org-better-agenda-setup` afterwards to apply the change):

```emacs-lisp
;; English (default)
(setq org-better-agenda-language 'en)

;; Norwegian
(setq org-better-agenda-language 'no)

;; Italian
(setq org-better-agenda-language 'it)

;; German
(setq org-better-agenda-language 'de)
```

## Recommended config

`recommended-config-for-org-better-agenda.el` is recommended if you're new to Org-Agenda and want to get started quickly. Load it after the main package:

```emacs-lisp
(require 'recommended-config-for-org-better-agenda)
```

Or with use-package:

```emacs-lisp
(use-package recommended-config-for-org-better-agenda
  :load-path "/path/to/org-better-agenda"
  :after org-better-agenda)
```

Or copy it into your init file to make changes as you see fit.

It provides:

- **Capture templates** for tasks and events
- **Keybindings** in `org-agenda-mode-map`
- **Everforest-style colors** for agenda views

### Capture templates

| Key | Description |
|---|---|
| `t` | Someday task |
| `d` | Task with deadline |
| `s` | Scheduled task |
| `b` | Scheduled task with deadline |
| `e` | Event |
| `w` | Weekly event |
| `m` | Monthly event |
| `y` | Yearly event |

Captured entries go to the file set by `org-better-agenda-inbox-file` (default: `~/inbox.org`), which is also added to `org-agenda-files`. Set it before loading the recommended config to use a different path:

```emacs-lisp
(setq org-better-agenda-inbox-file "~/org/inbox.org")
```

### Keybindings

| Key | Command |
|---|---|
| `d` | Set deadline (`org-agenda-deadline`) |
| `s` | Schedule (`org-agenda-schedule`) |
| `e` | Change timestamp at point (`org-agenda-date-prompt`) |
| `\` | Set tags (`org-agenda-set-tags`) |
| `T` | Toggle tag display |
| `L` | Cycle through available languages |

### Colors

Face settings are tuned for [Everforest](https://github.com/sainnhe/everforest)-style themes.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
