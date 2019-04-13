;;; julia-dumbcompleter --- Company backend for DumbCompleter.jl

;;; Commentary:
;;; Why does Flycheck always tell me to write this section?

;;; Code:

(require 'company)
(require 'json)

(defconst jldc/process-name "DumbCompleter.jl")
(setq jldc/process nil)
(setq jldc/last-result nil)

(defun jldc/activate (path)
  "Activate (load completions of) the project at PATH."
  (interactive "sPath to package: ")
  (jldc/init)
  (let* ((command `((type . activate) (path . ,path)))
         (json (json-encode command)))
    (jldc/send-input json)))


(defun jldc/backend (command &optional arg &rest ignored)
  "Responds to a company COMMAND with optional ARG and the rest IGNORED."
  (case command
    (interactive (company-begin-backend 'jldc/backend))
    ;; TODO: A prefix function that also captures the module.
    (prefix (and (eq major-mode 'julia-mode) (company-grab-symbol)))
    (candidates (jldc/completions arg))))

(defun jldc/init ()
  "Create a Julia process for DumbCompleter.jl."
  (unless (jldc/is-process-running)
    (setq jldc/process
          (make-process
           :name jldc/process-name
           :command '("julia" "--project" "-e" "using DumbCompleter; ioserver()")
           :filter (lambda (proc out) (setq jldc/last-result out))))))

(defun jldc/completions (arg)
  "Get completions for ARG."
  (jldc/init)
  (setq jldc/last-result nil)
  (jldc/send-command arg)
  (when (and (sit-for 0.1) jldc/last-result)
    (let* ((results (json-read-from-string jldc/last-result))
           (err (cdr (assq 'error results)))
           (completions (cdr (assq 'completions results))))
      (unless err (mapcar (lambda (c) (cdr (assq 'name c))) completions)))))

(defun jldc/send-command (arg)
  "Send a completions request for ARG."
  (let* ((module (when (string-match "\\." arg) (f-no-ext arg)))
         (text (or (f-ext arg) arg))
         (command `((type . completions) (module . ,module) (text . ,text)))
         (json (json-encode command)))
    (jldc/send-input json)))

(defun jldc/is-process-running ()
  "Determine whether the Julia process is running."
  (and jldc/process (eq (process-status jldc/process) 'run)))

(defun jldc/send-input (s)
  "Send S to the Julia process."
  (when (jldc/is-process-running)
    (process-send-string jldc/process (concat s "\n"))))

(defun jldc/stop-process ()
  "Stop the DumbCompleter.jl process."
  (when jldc/process
    (process-send-eof jldc/process)
    (process-send-eof jldc/process)))

(add-to-list 'company-backends 'jldc/backend)

(provide 'julia-dumbcompleter)

;;; julia-dumbcompleter.el ends here
