;;; emacs-term-toggle.el --- Toggle to and from the *terminal* buffer   -*- lexical-binding: t; -*-

;; Filename: term-toggle.el
;; Description: Toggle a dedicated terminal
;; Author: Joseph <jixiuf@gmail.com>, Yatao <yatao.li@live.com>, Arthur <arthur.miller@live.com>
;; Created: 2011-03-02
;; Version: 2.0.0
;; URL: https://github.com/amno1/emacs-term-toggle
;; Keywords:  term toggle shell
;; Compatibility: (Test on GNU Emacs 28.0.50).
;;
;;; License
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;; Code

;;; Customizable Options:
(defgroup term-toggle nil
  "Quake style console toggle in current working directory.
Support toggle for shell, term, ansi-term, eshell and ielm."
  :prefix "term-toggle-"
  :prefix "tt-"
  :group 'applications)

(defcustom term-toggle-confirm-exit nil
  "Ask to confirm exit if there is a running bash process in terminal."
  :type 'boolean
  :group 'term-toggle)

(defcustom term-toggle-kill-buffer-on-process-exit t
  "Kill buffer when shell process has exited."
  :type 'boolean
  :group 'term-toggle)

(defcustom term-toggle-minimum-split-height 10
  "The minimum height of a splittable window"
  :type 'fixnum
  :group 'term-toggle)

(defcustom term-toggle-default-height 15
  "The default height of a splitted window."
  :type 'fixnum
  :group 'term-toggle)

;;; Internal functions and declarations
(defun tt--start (shell name)
  (if (or (eq shell 'term) (eq shell 'ansi-term))
      (funcall shell (getenv "SHELL"))
    (funcall shell))
  (when-let ((proc (get-buffer-process (get-buffer name))))
    (set-process-query-on-exit-flag proc term-toggle-confirm-exit)
    (when term-toggle-kill-buffer-on-process-exit
      (set-process-sentinel
       proc (lambda (__ evt)
              (when (string-match-p "\\(?:exited\\|finished\\)" evt)
                (kill-buffer)))))))

(defun tt--toggle (term-buffer)
  (if-let ((term-window (get-buffer-window term-buffer)))
    (progn
      (bury-buffer term-buffer)
      (delete-window term-window))
    (split-window-vertically)
    (other-window 1)
    (pop-to-buffer-same-window term-buffer t)
    (set-window-dedicated-p term-window t)
    (when (>= (window-total-height (selected-window))
              term-toggle-minimum-split-height)
      (let ((delta (- (window-height (selected-window)) term-toggle-default-height)))
        (when (> delta 0) (shrink-window delta))))))

(defun term-toggle (shell)
  (let ((name (format "*%s*" (if (eq shell 'term) "terminal" shell)))
        (original-buffer (current-buffer)))
    (unless (get-buffer name)
      (tt--start shell name)
      (pop-to-buffer-same-window original-buffer))
    (tt--toggle (get-buffer name))))

;;; Commands
;;;###autoload
(defun term-toggle-term ()
  "Toggle `term'."
  (interactive) (term-toggle 'term))

;;;###autoload
(defun term-toggle-shell ()
  "Toggle `shell'."
  (interactive) (term-toggle 'shell))

;;;###autoload
(defun term-toggle-ansi ()
  "Toggle `ansi-term'."
  (interactive) (term-toggle 'ansi-term))

;;;###autoload
(defun term-toggle-eshell ()
  "Toggle `eshell'."
  (interactive) (term-toggle 'eshell))

;;;###autoload
(defun term-toggle-ielm ()
  "Toggle `ielm'."
  (interactive) (term-toggle 'ielm))

(provide 'term-toggle)

;;; emas-term-toggle.el ends here
