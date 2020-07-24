;;; package --- Emacs minor mode to help you check your flow types
;;;
;;; Commentary:
;;; flowmacs provides a few function to make checking and working
;;; with your Flow types easier.
;;;
;;; License: MIT

(require 'xref)

;;; Code:
(defgroup flowmacs nil
  "Minor mode to check flow types."
  :group 'languages
  :prefix "flowmacs"
  :link '(url-link :tag "Repository" "https://github.com/CodyReichert/flowmacs"))

(defcustom flowmacs/+flow+
  "flow"
  "The `flow` command."
  :type 'string
  :group 'flowmacs)

(defcustom flowmacs/+flow-buffer+
  "*Flow Output*"
  "Name of the flowmacs output buffer."
  :type 'string
  :group 'flowmacs)

(defun flowmacs/get-flow-buffer ()
  "Kill existing *Flow Output* buffers and return the name."
  (when (get-buffer flowmacs/+flow-buffer+)
    (kill-buffer flowmacs/+flow-buffer+))
  flowmacs/+flow-buffer+)

;;;
;;; Helpful things exposed by this package
;;;

(defun flowmacs/start-flow ()
  "Start the flow server."
  (shell-command (format "%s start" flowmacs/+flow+)))

(defun flowmacs/stop-flow ()
  "Stop the flow server."
  (shell-command (format "%s stop" flowmacs/+flow+)))

;; flow-status

(defcustom flowmacs/+flow-status-args+
  "--quiet --from emacs"
  "Command line arguments passed to flow-status."
  :type 'string
  :group 'flowmacs)

(defun flowmacs/flow-status ()
  "Call flow status and print the results."
  (interactive)
  (let* ((cmd (format "%s status %s"
                      flowmacs/+flow+
                      flowmacs/+flow-status-args+))
         (out (shell-command-to-string cmd)))
    (switch-to-buffer-other-window (flowmacs/get-flow-buffer))
    (insert out)
    (compilation-mode)))

;; flow-type-at-pos

(defcustom flowmacs/+type-at-pos-args+
  "--quiet --from emacs"
  "Command line arguments passed to flow-type-at-pos."
  :type 'string
  :group 'flowmacs)

(defun flowmacs/type-at-pos ()
  "Show type of value under cursor."
  (interactive)
  (let* ((file (buffer-file-name))
         (line (line-number-at-pos))
         (col (current-column))
         (buffer (current-buffer))
         (cmd (format
               "%s type-at-pos %s %s %d %d"
               flowmacs/+flow+
               flowmacs/+type-at-pos-args+
               file
               line
               (1+ col)))
         (out (shell-command-to-string cmd)))
    (switch-to-buffer-other-window (flowmacs/get-flow-buffer))
    (insert out)
    (compilation-mode)))
    ;; Alternatively, we can use `display-message-or-buffer':
    ;; (display-message-or-buffer out (flowmacs/get-flow-buffer))))

;; flow-find-refs

(defun flowmacs/find-refs ()
  "Find references to the current value at point."
  (interactive)
  (let* ((file (buffer-file-name))
         (line (line-number-at-pos))
         (col (current-column))
         (buffer (current-buffer))
         (cmd (format
               "%s find-refs --quiet --from emacs %s %d %d; exit 0"
               flowmacs/+flow+ file line (1+ col)))
         (out (shell-command-to-string cmd)))
    (switch-to-buffer-other-window (flowmacs/get-flow-buffer))
    (insert (flowmacs/clean-flow-output out))
    (compilation-mode)))

(defun flowmacs/suggest-types ()
  "Update the buffer with types suggested by `flow suggest`."
  (interactive)
  (let* ((file (buffer-file-name))
         (cmd (format "%s suggest %s" flowmacs/+flow+ file))
         (out (shell-command-to-string cmd))
         (new (flowmacs/clean-flow-output out)))
    (if new
        (progn
          (goto-char (point-min))
          (erase-buffer)
          (insert new)
          (message "[flowmacs] Buffer updated with flow suggested types"))
      (message (format "[flowmacs] Could not suggest types for %s" file)))))

(defun flowmacs/jump-to-def ()
  "Jump to type definition of value under point."
  (interactive)
  (let* ((file (buffer-file-name))
         (line (line-number-at-pos))
         (col (current-column))
         (buffer (current-buffer))
         (cmd (format
               "%s get-def --from emacs %s %d %d"
               flowmacs/+flow+ file line (1+ col)))
         (out (shell-command-to-string cmd))
         (line (flowmacs/line-number-from-flow out))
         (char (flowmacs/char-number-from-flow out))
         (file (flowmacs/file-path-from-flow out)))
    (if (> (length file) 0)
        (progn
          (xref-push-marker-stack)
          (find-file file)
          (goto-char (point-min))
          (forward-line (1- (string-to-number line)))
          (xref-pulse-momentarily))
      (message "[flowmacs] No matching definitions found"))))

;;;
;;; Helper functions for working with Flow output
;;;

(defun flowmacs/file-path-from-flow (out)
  "Parse an absolute file path from Flow's output OUT."
  (if (and out (member "File" (split-string out)))
      (replace-regexp-in-string
       "," ""
       (replace-regexp-in-string
        "\"" ""
        (cadr (member "File" (split-string out)))))
    nil))

(defun flowmacs/line-number-from-flow (out)
  "Parse the line number from Flow's output OUT."
  (if (and out (member "line" (split-string out)))
      (cadr (member "line" (split-string out)))
    nil))

(defun flowmacs/char-number-from-flow (out)
  "Parse the column number from Flow's output OUT."
  (if (and out (member "characters" (split-string out)))
      (car (split-string (cadr (member "characters" (split-string out))) "-"))
    nil))

(defun flowmacs/clean-flow-output (out)
  "Parse OUT from `flow suggest`."
  (if out
      (replace-regexp-in-string
       "Please wait. Server is handling a request (starting up)"
       ""
       out)
    nil))


;;;###autoload
(define-minor-mode flowmacs-mode
  "Enable flowmacs minor mode for check flow types."
  :lighter " Flow"
  :global nil)

(provide 'flowmacs)
;;; flowmacs.el ends here
