;;; term-toggle-animate.el --- Quake-style slide-in for term-toggle  -*- lexical-binding: t; -*-

;; Filename: term-toggle-animate.el
;; Description: Optional animation for term-toggle pop-ups
;; Author: Arthur <arthur.miller@live.com>
;; Version: 1.1.0
;; URL: https://github.com/amno1/emacs-term-toggle
;; Keywords: term toggle shell animation
;; Package-Requires: ((emacs "25.1") (term-toggle "2.3.0"))
;; Compatibility: (Test on GNU Emacs 28.0.50).

;;; License
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;;; Commentary:
;;
;; Optional companion to term-toggle.el.  Provides a global minor mode,
;; `term-toggle-animate-mode', which installs an animated replacement
;; for `tt--toggle' via `:override' advice.  When enabled, the pop-up
;; slides in and out one line (or column) at a time.  When disabled,
;; the plain implementation from term-toggle.el is restored.
;;
;; Load it after term-toggle.el:
;;
;;   (require 'term-toggle)
;;   (require 'term-toggle-animate)
;;
;; The mode is enabled by default.  Turn it off with:
;;
;;   (term-toggle-animate-mode -1)
;;
;; or interactively with M-x term-toggle-animate-mode.

;;; Code:

(require 'term-toggle)

;;; Customizable Options:

(defcustom term-toggle-side-max-fraction 0.5
  "Maximum fraction of the frame width a side pop-up may take."
  :type 'number
  :group 'term-toggle)

(defcustom term-toggle-animation-delay 0.008
  "Seconds to pause between animation frames.

The default gives roughly a 100 ms slide for a 15-line pop-up."
  :type 'number
  :group 'term-toggle)

;;; Internal state

;;; Internal functions

(defun tt--animate-window-size (window horizontal)
  "Return WINDOW's total height, or total width if HORIZONTAL."
  (if horizontal
      (window-total-width window)
    (window-total-height window)))

(defun tt--animate-target (horizontal)
  "Return the target size for a pop-up in direction HORIZONTAL.

Vertical pop-ups use `term-toggle-default-height'.  Horizontal
ones use `term-toggle-default-width', capped at
`term-toggle-side-max-fraction' of the frame width so the original
window always keeps a usable share.  In both cases the frame
keeps at least four lines (or columns) for the other window."
  (let* ((frame-size (if horizontal (frame-width) (frame-height)))
         (default (if horizontal term-toggle-default-width
                    term-toggle-default-height))
         (fraction (if (and (numberp term-toggle-side-max-fraction)
                            (> term-toggle-side-max-fraction 0)
                            (<= term-toggle-side-max-fraction 1))
                       term-toggle-side-max-fraction
                     0.5))
         (cap (if horizontal
                  (min (floor (* frame-size fraction))
                       (- frame-size 4))
                (- frame-size 4))))
    (max 1 (min default cap))))

(defun tt--animate-shrink-to-min (window horizontal)
  "Shrink WINDOW to the smallest legal size for animation.

The horizontal direction starts at width 2, because Emacs refuses
to make a window narrower than its compiled-in safe minimum.
`auto-hscroll-mode' is disabled and `window-hscroll' is reset, for
the same reason as in `tt--animate-stepwise'."
  (with-selected-window window
    (let ((window-min-height 1)
          (window-min-width 1)
          (auto-hscroll-mode nil))
      (set-window-hscroll window 0)
      (let* ((minimum (if horizontal 2 1))
             (delta (- (tt--animate-window-size window horizontal) minimum)))
        (when (> delta 0)
          (condition-case nil
              (shrink-window delta horizontal)
            (error nil)))))))

(defun tt--animate-settle (window horizontal target)
  "Ensure WINDOW ends the animation at TARGET with no hscroll.

Guarantees the target size even if `tt--animate-stepwise' bailed
out early, and resets horizontal scroll, which redisplay may have
set during the animation to keep point visible in a narrow window."
  (with-selected-window window
    (let ((window-min-height 1)
          (window-min-width 1))
      (let ((delta (- target (tt--animate-window-size window horizontal))))
        (when (/= delta 0)
          (ignore-errors (enlarge-window delta horizontal)))))
    (set-window-hscroll window 0)))

(defun tt--animate-stepwise (window horizontal target)
  "Move WINDOW one line (or column) at a time towards TARGET.

The buffer-local process-size adjuster is replaced with `ignore'
for the duration of the animation, so no `SIGWINCH' reaches the
child.  Line truncation is forced so Emacs does not rewrap the
display, `auto-hscroll-mode' is disabled, and `window-hscroll' is
reset, so redisplay cannot shift the terminal content sideways as
the window narrows."
  (with-selected-window window
    (let ((window-min-height 1)
          (window-min-width 1)
          (truncate-lines t)
          (truncate-partial-width-windows t)
          (auto-hscroll-mode nil))
      (set-window-hscroll window 0)
      (catch 'done
        (while (/= (tt--animate-window-size window horizontal) target)
          (let* ((current (tt--animate-window-size window horizontal))
                 (step (if (< current target) 1 -1)))
            (condition-case nil
                (enlarge-window step horizontal)
              (error (throw 'done nil)))
            (when (= current (tt--animate-window-size window horizontal))
              (throw 'done nil))
            (sit-for term-toggle-animation-delay)))))))

(defun tt--animate-sync-process-size (window)
  "Reconcile WINDOW's process and terminal state with WINDOW's size.

Sends `SIGWINCH' to the child and, in term buffers, updates the
buffer-local `term-width'/`term-height' that term.el uses to lay
out output.  Called once, at the very start and at the very end of
the slide, so the terminal emulator's geometry is always the
target geometry and never an intermediate one."
  (let* ((buf (window-buffer window))
         (proc (get-buffer-process buf)))
    (when proc
      (with-current-buffer buf
        (let ((height (window-body-height window))
              (width (window-body-width window)))
          (when (fboundp 'term-reset-size)
            (condition-case nil
                (term-reset-size height width)
              (error nil)))
          (set-process-window-size proc height width))))))

(defun tt-animate--suppress-adjuster (buffer)
  "Replace BUFFER's process-size adjuster with `ignore'.

Returns the previous buffer-local value, or the symbol `:unbound'
if BUFFER had no buffer-local value.  The return value is meant to
be handed back to `tt-animate--restore-adjuster'."
  (with-current-buffer buffer
    (prog1 (if (local-variable-p
                'window-adjust-process-window-size-function)
               window-adjust-process-window-size-function
             :unbound)
      (setq-local window-adjust-process-window-size-function #'ignore))))

(defun tt-animate--restore-adjuster (buffer saved)
  "Restore BUFFER's process-size adjuster from SAVED.

SAVED is the value returned by `tt-animate--suppress-adjuster'."
  (with-current-buffer buffer
    (if (eq saved :unbound)
        (kill-local-variable 'window-adjust-process-window-size-function)
      (setq-local window-adjust-process-window-size-function saved))))

;;; Animated toggle

(defun tt-animate--toggle (buffer)
  "Animated version of `tt--toggle'.

Installed via `:override' advice while
`term-toggle-animate-mode' is enabled.  The pop-up is created at
its target size so the terminal emulator commits to the correct
layout *before* the slide begins, and the buffer-local process
adjuster stays suppressed until the window is fully gone, so no
redisplay pass can reconcile term.el to the shrunken geometry."
  (let* ((side term-toggle-split-side)
         (horizontal (memq side '(left right)))
         (window (get-buffer-window buffer)))
    (if window
        (let ((saved (tt-animate--suppress-adjuster buffer)))
          (unwind-protect
              (progn
                (tt--animate-stepwise window horizontal
                                      (if horizontal 2 1))
                (set-window-dedicated-p window nil)
                (bury-buffer buffer)
                (delete-window window))
            ;; Restore only after the window has been removed, so no
            ;; redisplay can see the terminal buffer in a small window
            ;; while the adjuster is live.
            (tt-animate--restore-adjuster buffer saved)))
      (let* ((target (tt--animate-target horizontal))
             (new-window
              (let ((window-min-height 1)
                    (window-min-width 1))
                (split-window nil target side)))
             (saved (tt-animate--suppress-adjuster buffer)))
        (set-window-buffer new-window buffer)
        (tt--animate-sync-process-size new-window)
        (unwind-protect
            (progn
              (tt--animate-shrink-to-min new-window horizontal)
              (tt--animate-stepwise new-window horizontal target))
          (tt-animate--restore-adjuster buffer saved))
        (tt--animate-settle new-window horizontal target)
        (set-window-dedicated-p new-window t)
        (select-window new-window)))))

;;; Minor mode

(defun tt-animate--install ()
  "Install the animated `tt--toggle' via `:override' advice."
  (advice-add 'tt--toggle :override #'tt-animate--toggle))

(defun tt-animate--uninstall ()
  "Restore the plain `tt--toggle' from term-toggle.el."
  (advice-remove 'tt--toggle #'tt-animate--toggle))

(define-minor-mode term-toggle-animate-mode
  "Global minor mode to animate term-toggle pop-ups.

When enabled, `tt--toggle' is overridden with an animated version
that slides the pop-up in and out one line (or column) at a time.
When disabled, the plain implementation from term-toggle.el is
restored.

The mode has no keymap and no lighter; it exists only to install
or remove the `:override' advice on `tt--toggle'."
  :global t
  :lighter nil
  :group 'term-toggle
  (if term-toggle-animate-mode
      (tt-animate--install)
    (tt-animate--uninstall)))

(term-toggle-animate-mode 1)

(provide 'term-toggle-animate)
;;; term-toggle-animate.el ends here
