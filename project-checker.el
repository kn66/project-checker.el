;;; project-checker.el --- Automatic project and file checking -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;; Author: Your Name <your.email@example.com>
;; Version: 1.0.0
;; Package-Requires: ((emacs "27.1") (project "0.8.1"))
;; Keywords: tools, convenience, project, linting, testing
;; URL: https://github.com/yourusername/project-checker

;; This file is not part of GNU Emacs.

;;; Commentary:

;; project-checker provides automatic project-wide and file-specific checking
;; capabilities for Emacs. It integrates with your existing development workflow
;; by running specified commands automatically when files are saved, and provides
;; manual commands for project-wide checks.

;; Features:
;; - Automatic file-specific checks on save (linting, formatting, etc.)
;; - Manual project-wide checks (tests, full project linting)
;; - Integration with Emacs compilation mode for error navigation
;; - Per-project configuration using .dir-locals.el
;; - Support for any shell command or build tool

;; Basic usage:
;; 1. Enable project-checker-mode in your programming buffers
;; 2. Configure commands via .dir-locals.el or buffer-local variables
;; 3. Files are automatically checked on save
;; 4. Run M-x project-checker-run-project-commands for full project checks

;; Example configuration in .dir-locals.el:
;; ((nil . ((project-checker-project-commands . ("npm test" "npm run lint"))
;;          (project-checker-file-commands . ("eslint %s" "prettier --check %s")))))

;;; Code:

(require 'project)
(require 'compile)

;;; Customization

(defgroup project-checker nil
  "Automatic project and file checking."
  :group 'tools
  :prefix "project-checker-")

;;; Variables

(defvar-local project-checker-project-commands nil
  "List of shell commands to run for full project check.

Each command in the list will be executed in the project root directory
when `project-checker-run-project-commands' is called.

Example:
  (setq-local project-checker-project-commands
              '(\"npm test\"
                \"npm run lint\"
                \"npm run type-check\"))")

(defvar-local project-checker-file-commands nil
  "List of command templates for checking a single file.

Each template can contain the following placeholders:
- %s: full file path (relative to project root)
- %n: file path without extension
- %b: basename without directory and extension
- %d: directory path

Commands are executed automatically when the file is saved and
project-checker-mode is enabled.

Example:
  (setq-local project-checker-file-commands
              '(\"eslint %s\"
                \"prettier --check %s\"
                \"jest %n.test.ts\"))")

;;; Internal Functions

(defun project-checker--run-command (name command)
  "Run shell COMMAND in a compilation buffer named project-checker:NAME.

The command is executed in the project root directory. Results are
displayed in a compilation-mode buffer, allowing for easy navigation
to errors and warnings."
  (let ((bufname (format "*project-checker:%s*" name)))
    (compilation-start
     command 'compilation-mode (lambda (_) bufname))))

(defun project-checker--run-project-commands ()
  "Run all commands defined in project-checker-project-commands.

Each command is executed in a separate compilation buffer. If
project-checker-project-commands is nil or empty, no commands are run."
  (when project-checker-project-commands
    (dolist (cmd project-checker-project-commands)
      (project-checker--run-command cmd cmd))))

(defun project-checker--expand-file-template (template file)
  "Expand TEMPLATE with file placeholders.

Supported placeholders:
- %s: full file path
- %n: file path without extension
- %b: basename without directory and extension
- %d: directory path"
  (let* ((file-no-ext (file-name-sans-extension file))
         (basename (file-name-base file))
         (directory (file-name-directory file)))
    (format-spec
     template
     `((?s . ,file)
       (?n . ,file-no-ext)
       (?b . ,basename)
       (?d . ,(or directory ""))))))

(defun project-checker--run-file-commands ()
  "Run file-specific commands using project-checker-file-commands.

Commands are only run if:
- project-checker-file-commands is configured
- current buffer has an associated file
- current buffer is part of a project

The file path passed to commands is relative to the project root."
  (when (and project-checker-file-commands buffer-file-name)
    (let ((project (project-current)))
      (if project
          (let* ((file
                  (file-relative-name buffer-file-name
                                      (project-root project))))
            (dolist (template project-checker-file-commands)
              (let ((cmd
                     (project-checker--expand-file-template
                      template file)))
                (project-checker--run-command
                 (format "%s:%s" template file) cmd))))
        (message
         "project-checker: No project found for current buffer")))))

;;; Interactive Commands

;;;###autoload
(defun project-checker-run-project-commands ()
  "Manually run all project-wide checks.

Executes all commands in project-checker-project-commands. Each command
runs in a separate compilation buffer. If no commands are configured,
displays a message instead of failing silently."
  (interactive)
  (if project-checker-project-commands
      (project-checker--run-project-commands)
    (message "project-checker: No project commands configured")))

;;; Minor Mode

;;;###autoload
(define-minor-mode project-checker-mode
  "Minor mode to run file-specific checks automatically on save.

When enabled, commands in project-checker-file-commands are executed
automatically whenever the current buffer is saved.

Use `project-checker-run-project-commands' to run project-wide checks manually.

The mode integrates with Emacs' compilation system, so you can navigate
to errors and warnings using standard compilation commands like
`next-error' and `previous-error'.

\\{project-checker-mode-map}"
  :lighter " Check"
  :group
  'project-checker
  (if project-checker-mode
      (add-hook 'after-save-hook #'project-checker--run-file-commands
                nil
                t)
    (remove-hook 'after-save-hook #'project-checker--run-file-commands
                 t)))

;;; Setup Function

;;;###autoload
(defun project-checker-setup ()
  "Set up project-checker-mode for programming modes.

Adds project-checker-mode to prog-mode-hook, so it's automatically
enabled for all programming language buffers."
  (add-hook 'prog-mode-hook #'project-checker-mode))

(provide 'project-checker)

;;; project-checker.el ends here
