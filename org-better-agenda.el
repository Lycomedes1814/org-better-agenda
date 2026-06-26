;;; org-better-agenda.el --- Custom org-agenda view -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:
;; Custom agenda view with opinionated sorting and highlighting.
;; Multilingual support (currently English, Norwegian, Italian, German).
;; Requires org and org-agenda.  Integrates with org-modern if available.

;;; Code:

(require 'org)
(require 'org-agenda)
(require 'org-modern nil t)             ; soft dependency — used if present

;;; Customization group

(defgroup org-better-agenda nil
  "Customization for org-better-agenda."
  :group 'org-agenda
  :prefix "org-better-agenda-")

;;; Localization

(defcustom org-better-agenda-language-setup
  '((en . ((months        . ["" "January" "February" "March" "April" "May" "June"
                              "July" "August" "September" "October" "November" "December"])
           ;; Sunday = index 0 … Saturday = index 6, matching calendar-day-of-week
           (day-names     . ["Sunday" "Monday" "Tuesday" "Wednesday"
                              "Thursday" "Friday" "Saturday"])
           (deadline-label    . "Deadline")
           (scheduled-label   . "Scheduled")
           (deadline-today    . "Deadline:  ")
           (deadline-future   . "In %3d d.: ")
           (deadline-past     . "%2d d. ago: ")
           (scheduled-today   . "Scheduled: ")
           (scheduled-past    . "Sched.%2dx: ")
           (now-label         . "now")
           (must-do-header    . "Must do")
           (someday-header    . "When I have time")
           (view-title        . "Tasks")))
    (no . ((months        . ["" "januar" "februar" "mars" "april" "mai" "juni"
                              "juli" "august" "september" "oktober" "november" "desember"])
           (day-names     . ["Søndag" "Mandag" "Tirsdag" "Onsdag"
                              "Torsdag" "Fredag" "Lørdag"])
           (deadline-label    . "Frist")
           (scheduled-label   . "Planlagt")
           (deadline-today    . "Frist:     ")
           (deadline-future   . "Om %3d d.: ")
           (deadline-past     . "%2d d. siden: ")
           (scheduled-today   . "Planlagt:  ")
           (scheduled-past    . "Plan.%2dx: ")
           (now-label         . "nå")
           (must-do-header    . "Må gjøres")
           (someday-header    . "Når jeg har tid")
           (view-title        . "Oppgaver")))
    (it . ((months        . ["" "gennaio" "febbraio" "marzo" "aprile" "maggio" "giugno"
                              "luglio" "agosto" "settembre" "ottobre" "novembre" "dicembre"])
           (day-names     . ["Domenica" "Lunedì" "Martedì" "Mercoledì"
                              "Giovedì" "Venerdì" "Sabato"])
           (deadline-label    . "Scadenza")
           (scheduled-label   . "Pianificato")
           (deadline-today    . "Scadenza:  ")
           (deadline-future   . "Fra %3d g.: ")
           (deadline-past     . "%2d g. fa:  ")
           (scheduled-today   . "Pianif.:   ")
           (scheduled-past    . "Pian.%2dx: ")
           (now-label         . "adesso")
           (must-do-header    . "Da fare")
           (someday-header    . "Quando ho tempo")
           (view-title        . "Attività")))
    (de . ((months        . ["" "Januar" "Februar" "März" "April" "Mai" "Juni"
                              "Juli" "August" "September" "Oktober" "November" "Dezember"])
           (day-names     . ["Sonntag" "Montag" "Dienstag" "Mittwoch"
                              "Donnerstag" "Freitag" "Samstag"])
           (deadline-label    . "Frist")
           (scheduled-label   . "Geplant")
           (deadline-today    . "Frist:     ")
           (deadline-future   . "In %3d T.: ")
           (deadline-past     . "Vor %2d T.: ")
           (scheduled-today   . "Geplant:   ")
           (scheduled-past    . "Gep.%2dx:  ")
           (now-label         . "jetzt")
           (must-do-header    . "Zu erledigen")
           (someday-header    . "Wenn ich Zeit habe")
           (view-title        . "Aufgaben"))))
  "Per-language string table for org-better-agenda.
Each entry is a cons of a language symbol and an alist of string keys.
Users can add new languages or override existing ones by customizing this
variable.  Required keys: months (vector of 13 strings, index 0 unused),
day-names (vector of 7 strings, Sunday first), deadline-label,
scheduled-label, deadline-today, deadline-future, deadline-past,
scheduled-today, scheduled-past, now-label, must-do-header,
someday-header, view-title."
  :type 'alist
  :group 'org-better-agenda)

(defcustom org-better-agenda-language 'en
  "Language for agenda labels and date formatting.
Supported values: `en' (English), `no' (Norwegian), `it' (Italian), `de' (German).
After changing this interactively, call `org-better-agenda-setup' to apply."
  :type '(choice (const :tag "English" en)
                 (const :tag "Norwegian" no)
                 (const :tag "Italian" it)
                 (const :tag "German" de))
  :group 'org-better-agenda
  :set (lambda (sym val)
         (set-default sym val)
         (when (featurep 'org-better-agenda)
           (org-better-agenda-setup))))

(defcustom org-better-agenda-must-do-deadline-days 60
  "Maximum days ahead to show deadline items in the Must do section.
Overdue deadlines are still shown.  Set to nil to show all deadlines."
  :type '(choice (const :tag "No limit" nil)
                 (integer :tag "Days"))
  :group 'org-better-agenda)

(defun org-better-agenda--str (key)
  "Return the localized string for KEY in `org-better-agenda-language'."
  (let ((table (alist-get org-better-agenda-language org-better-agenda-language-setup)))
    (alist-get key table)))

;;; Date formatting

(defun org-better-agenda-format-date (datestr)
  "Format Org DATESTR like <2026-04-04 Sat> as '4 April'.
Returns nil on any parse error so a bad timestamp never breaks the agenda."
  (when datestr
    (condition-case nil
        (let* ((ts (org-time-string-to-time datestr))
               (day (string-to-number (format-time-string "%d" ts)))
               (month (string-to-number (format-time-string "%m" ts))))
          (let ((month-name (aref (org-better-agenda--str 'months) month))
                (sep (if (memq org-better-agenda-language '(en it)) " " ". ")))
            (format "%d%s%s" day sep month-name)))
      (error nil))))

(defun org-better-agenda--days-until (datestr)
  "Return integer days from today until DATESTR, or nil on parse error."
  (when datestr
    (condition-case nil
        (- (org-time-string-to-absolute datestr)
           (time-to-days (current-time)))
      (error nil))))

(defun org-better-agenda--skip-current-subtree ()
  "Return the position after the current subtree for agenda skipping."
  (save-excursion
    (or (outline-next-heading) (goto-char (point-max)))
    (point)))

(defun org-better-agenda--skip-distant-deadline ()
  "Skip current entry when its DEADLINE is beyond the Must do deadline limit."
  (let ((deadline (org-entry-get nil "DEADLINE"))
        (limit org-better-agenda-must-do-deadline-days))
    (when (and deadline limit)
      (let ((days (org-better-agenda--days-until deadline)))
        (when (and days (> days limit))
          (org-better-agenda--skip-current-subtree))))))

(defun org-better-agenda-entry-date-info ()
  "Return readable DEADLINE/SCHEDULED info for the current agenda entry.
Shows both dates when present, separated by \" · \"."
  (let* ((el       (org-element-at-point))
         (dl-ts    (org-element-property :deadline el))
         (sc-ts    (org-element-property :scheduled el))
         (deadline  (when dl-ts (org-element-property :raw-value dl-ts)))
         (scheduled (when sc-ts (org-element-property :raw-value sc-ts)))
         (dl-label (org-better-agenda--str 'deadline-label))
         (sc-label (org-better-agenda--str 'scheduled-label))
         (parts
          (delq nil
                (list
                 (when scheduled
                   (format "%s: %s" sc-label (org-better-agenda-format-date scheduled)))
                 (when deadline
                   (format "%s: %s" dl-label (org-better-agenda-format-date deadline)))))))
    (string-join parts " · ")))

(defun org-better-agenda-entry-days-left ()
  "Return DEADLINE/SCHEDULED info showing days remaining as a colored Nd string."
  (let* ((el        (org-element-at-point))
         (dl-ts     (org-element-property :deadline el))
         (sc-ts     (org-element-property :scheduled el))
         (deadline  (when dl-ts (org-element-property :raw-value dl-ts)))
         (scheduled (when sc-ts (org-element-property :raw-value sc-ts)))
         (parts
          (delq nil
                (list
                 (when deadline
                   (let ((days (org-better-agenda--days-until deadline)))
                     (when days (format "%3s" (format "%dd" days)))))))))
    (string-join parts " · ")))


;;; Agenda date header

(defun org-better-agenda-format-date-header (date)
  "Format DATE for the org-agenda date header using the current language.
DATE is a calendar list (MONTH DAY YEAR).  Mirrors the layout of
`org-agenda-format-date-aligned' but uses localized day and month names."
  (require 'cal-iso)
  (let* ((day         (cadr date))
         (day-of-week (calendar-day-of-week date))
         (month       (car date))
         (year        (nth 2 date))
         (iso-week    (org-days-to-iso-week
                       (calendar-absolute-from-gregorian date)))
         (day-name    (aref (org-better-agenda--str 'day-names) day-of-week))
         (month-name  (aref (org-better-agenda--str 'months) month))
         (weekstring  (if (= day-of-week 1)
                          (format " W%02d" iso-week)
                        ""))
         (day-str     (if (memq org-better-agenda-language '(en it))
                          (format "%2d" day)
                        (format "%d." day))))
    (format "%-8s %s %s %4d%s"
            day-name day-str month-name year weekstring)))

;;; Sorting

(defun org-better-agenda-entry-earliest-date ()
  "Return earliest of DEADLINE and SCHEDULED for current entry, or nil."
  (let* ((deadline (org-entry-get nil "DEADLINE"))
         (scheduled (org-entry-get nil "SCHEDULED"))
         (times (mapcar #'org-time-string-to-time
                        (delq nil (list deadline scheduled)))))
    (when times
      (car (sort times #'time-less-p)))))

(defun org-better-agenda--marker-from-entry (entry)
  "Return Org marker from agenda ENTRY string."
  (or (get-text-property 0 'org-marker entry)
      (get-text-property 0 'org-hd-marker entry)))

(defun org-better-agenda-cmp-earliest-date (a b)
  "Compare agenda entries A and B by earliest relevant date."
  (let ((ma (org-better-agenda--marker-from-entry a))
        (mb (org-better-agenda--marker-from-entry b))
        ta tb)
    (setq ta
          (when (and ma (marker-buffer ma))
            (with-current-buffer (marker-buffer ma)
              (goto-char ma)
              (org-better-agenda-entry-earliest-date))))
    (setq tb
          (when (and mb (marker-buffer mb))
            (with-current-buffer (marker-buffer mb)
              (goto-char mb)
              (org-better-agenda-entry-earliest-date))))
    (cond
     ((and ta tb)
      (cond
       ((time-less-p ta tb) -1)
       ((time-less-p tb ta) 1)
       (t nil)))
     (ta -1)
     (tb 1)
     (t nil))))

(defun org-better-agenda-cmp-allday-first (a b)
  "Sort all-day agenda entries before timed entries."
  (let ((ta (get-text-property 0 'time-of-day a))
        (tb (get-text-property 0 'time-of-day b)))
    (cond
     ((and (null ta) (null tb)) nil)
     ((null ta) -1)
     ((null tb) 1)
     (t nil))))

;;; Custom faces

(defface org-better-agenda-time-face
  '((t :inherit font-lock-type-face :weight bold))
  "Face for timed agenda entries.")

(defface org-better-agenda-allday-face
  '((t :inherit font-lock-string-face :slant italic))
  "Face for all-day agenda entries.")

(defface org-better-agenda-deadline-date-face
  '((t :inherit error :weight bold))
  "Face for deadline dates in custom agenda sections.")

(defface org-better-agenda-days-urgent-face
  '((t :foreground "#e05050" :weight bold))
  "Nd countdown face for deadlines within 7 days.")

(defface org-better-agenda-days-soon-face
  '((t :foreground "#e0a000" :weight bold))
  "Nd countdown face for deadlines within 8–14 days.")

(defface org-better-agenda-days-later-face
  '((t :foreground "#8a8a6a" :weight bold))
  "Nd countdown face for deadlines 15+ days away.")

(defface org-better-agenda-scheduled-date-face
  '((t :inherit font-lock-type-face :weight bold))
  "Face for scheduled dates in custom agenda sections.")

;;; Highlighting

(defun org-better-agenda-highlight-times ()
  "Highlight time ranges at the start of agenda lines."
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward
            "^  \\([0-9]\\{2\\}:[0-9]\\{2\\}\\(?:-[0-9]\\{2\\}:[0-9]\\{2\\}\\)?\\)"
            nil t)
      (put-text-property (match-beginning 1) (match-end 1)
                         'face 'org-better-agenda-time-face))))

(defun org-better-agenda-highlight-allday ()
  "Highlight all-day agenda entries.
Uses the `time-of-day' text property rather than layout heuristics."
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (let ((bol (line-beginning-position)))
        (when (and (eq (get-text-property bol 'org-agenda-type) 'agenda)
                   (null (get-text-property bol 'time-of-day))
                   (get-text-property bol 'org-marker))
          (put-text-property bol (line-end-position)
                             'face 'org-better-agenda-allday-face)))
      (forward-line 1))))

(defun org-better-agenda-highlight-date-info ()
  "Highlight date parts in deadline/scheduled agenda prefixes."
  (let ((dl-re (regexp-quote (org-better-agenda--str 'deadline-label)))
        (sc-re (regexp-quote (org-better-agenda--str 'scheduled-label))))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward
              (format "\\(%s:\\) \\([0-9]+\\.? [[:alpha:]]+\\)" dl-re)
              nil t)
        (put-text-property (match-beginning 1) (match-end 1) 'face 'default)
        (put-text-property (match-beginning 2) (match-end 2)
                           'face 'org-better-agenda-deadline-date-face)))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward
              (format "\\(%s:\\) \\([0-9]+\\.? [[:alpha:]]+\\)" sc-re)
              nil t)
        (put-text-property (match-beginning 1) (match-end 1) 'face 'default)
        (put-text-property (match-beginning 2) (match-end 2)
                           'face 'org-better-agenda-scheduled-date-face)))))

(defun org-better-agenda-highlight-days-left ()
  "Highlight Nd countdown strings in the must-do section with urgency colors."
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "\\( *\\(-?[0-9]+\\)d\\)\\b" nil t)
      (when (eq (get-text-property (line-beginning-position) 'org-agenda-type) 'tags)
        (let* ((days (string-to-number (match-string 2)))
               (face (cond ((<= days 7)  'org-better-agenda-days-urgent-face)
                           ((<= days 14) 'org-better-agenda-days-soon-face)
                           (t            'org-better-agenda-days-later-face))))
          (put-text-property (match-beginning 1) (match-end 1) 'face face))))))

;;; Finalize hook

(defun org-better-agenda-finalize ()
  "Apply custom styling after agenda generation."
  (org-better-agenda-highlight-allday)
  (when (fboundp 'org-modern-agenda)
    (org-modern-agenda))
  (org-better-agenda-highlight-times)
  (org-better-agenda-highlight-date-info)
  (org-better-agenda-highlight-days-left))

(add-hook 'org-agenda-finalize-hook #'org-better-agenda-finalize)

;;; Language toggle

(defun org-better-agenda-toggle-language ()
  "Cycle through available languages and refresh the agenda."
  (interactive)
  (let* ((langs (mapcar #'car org-better-agenda-language-setup))
         (next (cadr (member org-better-agenda-language langs)))
         (new-lang (or next (car langs))))
    (setq org-better-agenda-language new-lang)
    (org-better-agenda-setup)
    (org-better-agenda)
    (message "Language switched to %s" new-lang)))

;;; Tags toggle

(defun org-better-agenda-toggle-tags ()
  "Toggle tag display in the agenda and refresh."
  (interactive)
  (setq org-agenda-remove-tags (not org-agenda-remove-tags))
  (org-agenda-redo-all))

;;; Agenda display settings

(with-eval-after-load 'org-agenda
  (setq org-agenda-show-all-dates nil
        org-agenda-skip-scheduled-if-done t
        org-agenda-skip-deadline-if-done t
        org-deadline-warning-days 0
        org-agenda-scheduled-leaders '("" "")
        org-agenda-block-separator ?─
        org-agenda-tags-column 45
        org-tags-column 0
        org-agenda-remove-tags t
        org-agenda-format-date #'org-better-agenda-format-date-header
        org-agenda-time-grid
        '((daily today require-timed)
          (800 1200 1600 2000)
          "  ·  "
          "────────────────")
        org-agenda-prefix-format
        '((agenda . "  %-12t %s")
          (todo   . " %i ")
          (tags   . " %i %(org-better-agenda-entry-days-left) ")
          (search . " %i "))))

;;; Custom commands

;; "Must do": tasks with a DEADLINE or SCHEDULED date.
;; "When I have time": tasks with no DEADLINE, no SCHEDULED, and no active timestamp.
(defun org-better-agenda--build-command ()
  "Return the \"g\" agenda command spec for the current language."
  `("g" ,(org-better-agenda--str 'view-title)
    ((agenda ""
             ((org-agenda-span 30)
              (org-agenda-start-day "+0d")
              (org-agenda-start-on-weekday nil)
              (org-agenda-overriding-header "")
              (org-agenda-entry-types '(:scheduled :timestamp :sexp))
              (org-agenda-cmp-user-defined #'org-better-agenda-cmp-allday-first)
              (org-agenda-sorting-strategy '(user-defined-up time-up))))
     (tags-todo "+DEADLINE<>\"\""
                ((org-agenda-overriding-header
                  ,(org-better-agenda--str 'must-do-header))
                 (org-agenda-skip-function
                  #'org-better-agenda--skip-distant-deadline)
                 (org-agenda-cmp-user-defined
                  #'org-better-agenda-cmp-earliest-date)
                 (org-agenda-sorting-strategy
                  '(user-defined-up priority-down category-keep))))
     (tags-todo "-DEADLINE<>\"\"-SCHEDULED<>\"\"-TIMESTAMP<>\"\""
                ((org-agenda-overriding-header
                  ,(org-better-agenda--str 'someday-header)))))))

(defun org-better-agenda-setup ()
  "Register the \"g\" agenda command and apply language-specific settings.
Call this after changing `org-better-agenda-language' if you want the
command available in the standard org-agenda dispatcher (\\[org-agenda])."
  (setq org-agenda-custom-commands
        (assoc-delete-all "g" org-agenda-custom-commands))
  (add-to-list 'org-agenda-custom-commands
               (org-better-agenda--build-command))
  (setq org-agenda-current-time-string
        (format "◀ %s ──────────" (org-better-agenda--str 'now-label)))
  (setq org-agenda-deadline-leaders
        (list (org-better-agenda--str 'deadline-today)
              (org-better-agenda--str 'deadline-future)
              (org-better-agenda--str 'deadline-past)))
  (setq org-agenda-scheduled-leaders
        (list (org-better-agenda--str 'scheduled-today)
              (org-better-agenda--str 'scheduled-past))))

;;; Entry point

(defun org-better-agenda ()
  "Open the custom agenda view."
  (interactive)
  ;; Build the command inline so it always reflects the current language,
  ;; regardless of when setup was last called.
  (let ((org-agenda-custom-commands (list (org-better-agenda--build-command)))
        (org-agenda-current-time-string
         (format "◀ %s ──────────" (org-better-agenda--str 'now-label))))
    (org-agenda nil "g")))

;;; Initialize

(org-better-agenda-setup)

(provide 'org-better-agenda)
;;; org-better-agenda.el ends here
