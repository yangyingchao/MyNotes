#!/usr/bin/env sh
:; set -e # -*- mode: emacs-lisp; lexical-binding: t -*-
:; emacs --no-site-file --script "$0" -- "$@" || __EXITCODE=$?
:; exit ${__EXITCODE:-0}
;;; Code:
(defvar bootstrap-version)
(defvar straight-base-dir)
(defvar straight-fix-org)
(defvar straight-vc-git-default-clone-depth 1)
(defvar publish--straight-repos-dir)

(setq gc-cons-threshold 83886080 ; 80MiB
      straight-base-dir (expand-file-name "../.." (or load-file-name buffer-file-name))
      straight-fix-org t
      straight-vc-git-default-clone-depth 1
      publish--straight-repos-dir (expand-file-name "straight/repos/" straight-base-dir))

(let ((bootstrap-file (expand-file-name "straight/repos/straight.el/bootstrap.el" straight-base-dir))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
	(url-retrieve-synchronously
	 "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
	 'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;;; org && ox-hugo
(straight-use-package '(org :type built-in))
(straight-use-package
 '(ox-hugo :type git
	   :host github
	   :repo "kaushalmodi/ox-hugo"
	   :nonrecursive t))

(require 'ox-hugo)

(defun yc/org-hugo--build-toc-a (content)
  "Append my markers.

These markers are used to identify original source of this note."
  (concat (or content "")
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward (rx bol ":NOTER_DOCUMENT:" (* space) (group (+ nonl)) eol) nil t)
          (let ((orig (match-string 1)))
            (format "\n\n本文为摘录，原文为： %s\n" orig))
        ""))))

(advice-add #'org-hugo--build-toc :filter-return #'yc/org-hugo--build-toc-a)

(defun tnote/export-org-file-to-md (file)
  "Export single FILE to markdown."
  (message "Checking file %s" file)
  (if (and (file-exists-p file)
           (string-equal (file-name-extension file) "org")
           (not (string-match-p (rx (or "inbox" "gtd")) file)))
            (with-current-buffer (find-file-noselect file)
        (message "    Processing file: %s" file)
        (condition-case var
            (org-hugo-export-wim-to-md t)
          (error (message "ERROR: %s" var)))
        (message "    .... done"))
    (message "    Skipping file: %s" file)))

(defun batch-export-all-org-files-to-md (dir)
  "Export all org files in directory DIR to markdown.

To perform a full export of all org files in the directory DIR to
markdown format, use this command. It should be called when a
full export is required, typically for the first time.."
  (message "DIR: %s" dir)
  (mapc #'tnote/export-org-file-to-md (directory-files-recursively dir "\\`[^.#].*\\.org\\'")))

(defun batch-export-HEAD-files-to-md ()
  "Export the files in the HEAD branch to markdown format.

This command should be called in an incremental manner to
effectively export updated files.."
  (dolist (it (cdr (string-lines (shell-command-to-string "git show --oneline --name-only HEAD"))))
    (tnote/export-org-file-to-md (expand-file-name it ".."))))

;;; export
(setq org-hugo-base-dir (concat default-directory "../hugo"))
(setq org-file-dir (concat default-directory "../org/"))

(batch-export-all-org-files-to-md org-file-dir)
