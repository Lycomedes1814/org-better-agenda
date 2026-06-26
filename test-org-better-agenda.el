;;; org-better-agenda-test.el --- ERT tests for org-better-agenda -*- lexical-binding: t; -*-

;;; Commentary:
;; Run with: emacs -batch -L . -l org-better-agenda-test.el -f ert-run-tests-batch-and-exit

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'org)
(require 'org-better-agenda)

;;; Helpers

(defun ora-test--make-agenda-entry (&optional time-of-day)
  "Make a minimal agenda entry string, optionally with TIME-OF-DAY property."
  (let ((s (copy-sequence "Task title")))
    (when time-of-day
      (put-text-property 0 1 'time-of-day time-of-day s))
    s))

(defun ora-test--make-dated-entry (marker)
  "Make an agenda entry string carrying MARKER as `org-marker'."
  (let ((s (copy-sequence "Task title")))
    (put-text-property 0 1 'org-marker marker s)
    s))

(defmacro ora-test--with-org-entry (content &rest body)
  "Run BODY in a temp org buffer with CONTENT, point at the first heading.
The buffer is killed on exit; do not capture markers from this macro."
  (declare (indent 1))
  `(with-temp-buffer
     (org-mode)
     (insert ,content)
     (goto-char (point-min))
     ,@body))

(defmacro ora-test--with-live-org-buffers (bindings &rest body)
  "Bind (VAR CONTENT) pairs to live markers, run BODY, then kill the buffers.
Each VAR receives a marker at the first position of a persistent org buffer so
the buffer is not killed out from under the marker during BODY."
  (declare (indent 1))
  (let ((buf-syms (mapcar (lambda (_) (gensym "ora-buf-")) bindings)))
    `(let (,@(mapcar (lambda (bs) `(,bs nil)) buf-syms)
           ,@(mapcar (lambda (b)  `(,(car b) nil)) bindings))
       (unwind-protect
           (progn
             ,@(cl-mapcar
                (lambda (bs b)
                  `(progn
                     (setq ,bs (generate-new-buffer " *ora-test*"))
                     (with-current-buffer ,bs
                       (org-mode)
                       (insert ,(cadr b))
                       (goto-char (point-min))
                       (setq ,(car b) (point-marker)))))
                buf-syms bindings)
             ,@body)
         ,@(mapcar (lambda (bs)
                     `(when (buffer-live-p ,bs) (kill-buffer ,bs)))
                   buf-syms)))))

;;; org-better-agenda-format-date — English (default)

(ert-deftest ora/format-date/normal ()
  (should (equal (org-better-agenda-format-date "<2026-04-04 Sat>") "4 April")))

(ert-deftest ora/format-date/nil-input ()
  (should (null (org-better-agenda-format-date nil))))

(ert-deftest ora/format-date/january ()
  (should (equal (org-better-agenda-format-date "<2026-01-01 Thu>") "1 January")))

(ert-deftest ora/format-date/december ()
  (should (equal (org-better-agenda-format-date "<2026-12-31 Thu>") "31 December")))

(ert-deftest ora/format-date/malformed-returns-nil ()
  "A bad timestamp must not error — condition-case returns nil."
  (should (null (org-better-agenda-format-date "not-a-date"))))

(ert-deftest ora/format-date/with-time-component ()
  "Timestamps that include a time should still return just the date."
  (should (equal (org-better-agenda-format-date "<2026-06-15 Mon 14:30>") "15 June")))

(ert-deftest ora/format-date/with-repeater ()
  "Repeating timestamps should parse without error."
  (should (equal (org-better-agenda-format-date "<2026-04-04 Sat +1w>") "4 April")))

;;; org-better-agenda--days-until

(ert-deftest ora/days-until/same-calendar-day-is-zero ()
  (cl-letf (((symbol-function 'current-time)
             (lambda () (encode-time 0 0 12 26 6 2026))))
    (should (= 0 (org-better-agenda--days-until "<2026-06-26 Fri 23:00>")))))

(ert-deftest ora/days-until/timed-sixtieth-calendar-day-is-sixty ()
  (cl-letf (((symbol-function 'current-time)
             (lambda () (encode-time 0 0 12 26 6 2026))))
    (should (= 60 (org-better-agenda--days-until "<2026-08-25 Tue 23:00>")))))

;;; org-better-agenda--skip-distant-deadline

(ert-deftest ora/skip-distant-deadline/keeps-deadline-within-limit ()
  (let ((org-better-agenda-must-do-deadline-days 60))
    (ora-test--with-org-entry "* Task\nDEADLINE: <2026-07-01 Wed>\n"
      (cl-letf (((symbol-function 'org-better-agenda--days-until)
                 (lambda (_) 30)))
        (should (null (org-better-agenda--skip-distant-deadline)))))))

(ert-deftest ora/skip-distant-deadline/keeps-deadline-on-limit ()
  (let ((org-better-agenda-must-do-deadline-days 60))
    (ora-test--with-org-entry "* Task\nDEADLINE: <2026-08-25 Tue>\n"
      (cl-letf (((symbol-function 'org-better-agenda--days-until)
                 (lambda (_) 60)))
        (should (null (org-better-agenda--skip-distant-deadline)))))))

(ert-deftest ora/skip-distant-deadline/keeps-overdue-deadline ()
  (let ((org-better-agenda-must-do-deadline-days 60))
    (ora-test--with-org-entry "* Task\nDEADLINE: <2026-06-01 Mon>\n"
      (cl-letf (((symbol-function 'org-better-agenda--days-until)
                 (lambda (_) -25)))
        (should (null (org-better-agenda--skip-distant-deadline)))))))

(ert-deftest ora/skip-distant-deadline/skips-deadline-beyond-limit ()
  (let ((org-better-agenda-must-do-deadline-days 60))
    (ora-test--with-org-entry "* Task\nDEADLINE: <2026-08-26 Wed>\n"
      (cl-letf (((symbol-function 'org-better-agenda--days-until)
                 (lambda (_) 61)))
        (should (= (point-max)
                   (org-better-agenda--skip-distant-deadline)))))))

(ert-deftest ora/skip-distant-deadline/keeps-all-when-limit-disabled ()
  (let ((org-better-agenda-must-do-deadline-days nil))
    (ora-test--with-org-entry "* Task\nDEADLINE: <2027-01-01 Fri>\n"
      (cl-letf (((symbol-function 'org-better-agenda--days-until)
                 (lambda (_) 189)))
        (should (null (org-better-agenda--skip-distant-deadline)))))))

;;; org-better-agenda-format-date — Norwegian

(ert-deftest ora/format-date/norwegian-april ()
  "Norwegian locale uses ordinal period and lowercase month names."
  (let ((org-better-agenda-language 'no))
    (should (equal (org-better-agenda-format-date "<2026-04-04 Sat>") "4. april"))))

(ert-deftest ora/format-date/norwegian-january ()
  (let ((org-better-agenda-language 'no))
    (should (equal (org-better-agenda-format-date "<2026-01-01 Thu>") "1. januar"))))

(ert-deftest ora/format-date/norwegian-december ()
  (let ((org-better-agenda-language 'no))
    (should (equal (org-better-agenda-format-date "<2026-12-31 Thu>") "31. desember"))))

;;; org-better-agenda-format-date — German

(ert-deftest ora/format-date/german-april ()
  "German locale uses ordinal period and capitalized month names."
  (let ((org-better-agenda-language 'de))
    (should (equal (org-better-agenda-format-date "<2026-04-04 Sat>") "4. April"))))

(ert-deftest ora/format-date/german-january ()
  (let ((org-better-agenda-language 'de))
    (should (equal (org-better-agenda-format-date "<2026-01-01 Thu>") "1. Januar"))))

(ert-deftest ora/format-date/german-december ()
  (let ((org-better-agenda-language 'de))
    (should (equal (org-better-agenda-format-date "<2026-12-31 Thu>") "31. Dezember"))))

;;; org-better-agenda-cmp-allday-first

(ert-deftest ora/cmp-allday/both-allday ()
  (should (null (org-better-agenda-cmp-allday-first
                 (ora-test--make-agenda-entry)
                 (ora-test--make-agenda-entry)))))

(ert-deftest ora/cmp-allday/allday-sorts-before-timed ()
  (should (= -1 (org-better-agenda-cmp-allday-first
                 (ora-test--make-agenda-entry nil)
                 (ora-test--make-agenda-entry 1430)))))

(ert-deftest ora/cmp-allday/timed-sorts-after-allday ()
  (should (= 1 (org-better-agenda-cmp-allday-first
                (ora-test--make-agenda-entry 900)
                (ora-test--make-agenda-entry nil)))))

(ert-deftest ora/cmp-allday/both-timed-returns-nil ()
  "Two timed entries: allday comparator defers to other criteria."
  (should (null (org-better-agenda-cmp-allday-first
                 (ora-test--make-agenda-entry 900)
                 (ora-test--make-agenda-entry 1430)))))

;;; org-better-agenda-cmp-earliest-date
;;
;; These tests use `ora-test--with-live-org-buffers' because the comparator
;; dereferences markers into their source buffers.  `with-temp-buffer' kills
;; the buffer on exit, leaving dead markers before the assertion runs.

(ert-deftest ora/cmp-date/earlier-deadline-sorts-first ()
  (ora-test--with-live-org-buffers
      ((ma "* Task A\nDEADLINE: <2026-01-01 Thu>\n")
       (mb "* Task B\nDEADLINE: <2026-06-01 Mon>\n"))
    (let ((a (ora-test--make-dated-entry ma))
          (b (ora-test--make-dated-entry mb)))
      (should (= -1 (org-better-agenda-cmp-earliest-date a b)))
      (should (=  1 (org-better-agenda-cmp-earliest-date b a))))))

(ert-deftest ora/cmp-date/same-date-returns-nil ()
  (ora-test--with-live-org-buffers
      ((ma "* Task A\nDEADLINE: <2026-04-04 Sat>\n")
       (mb "* Task B\nDEADLINE: <2026-04-04 Sat>\n"))
    (should (null (org-better-agenda-cmp-earliest-date
                   (ora-test--make-dated-entry ma)
                   (ora-test--make-dated-entry mb))))))

(ert-deftest ora/cmp-date/dated-sorts-before-undated ()
  (ora-test--with-live-org-buffers
      ((ma "* Task A\nDEADLINE: <2026-04-04 Sat>\n")
       (mb "* Task B\n"))
    (let ((a (ora-test--make-dated-entry ma))
          (b (ora-test--make-dated-entry mb)))
      (should (= -1 (org-better-agenda-cmp-earliest-date a b)))
      (should (=  1 (org-better-agenda-cmp-earliest-date b a))))))

(ert-deftest ora/cmp-date/both-undated-returns-nil ()
  (ora-test--with-live-org-buffers
      ((ma "* Task A\n")
       (mb "* Task B\n"))
    (should (null (org-better-agenda-cmp-earliest-date
                   (ora-test--make-dated-entry ma)
                   (ora-test--make-dated-entry mb))))))

(ert-deftest ora/cmp-date/scheduled-used-when-no-deadline ()
  (ora-test--with-live-org-buffers
      ((ma "* Task A\nSCHEDULED: <2026-03-01 Sun>\n")
       (mb "* Task B\nDEADLINE: <2026-05-01 Fri>\n"))
    (should (= -1 (org-better-agenda-cmp-earliest-date
                   (ora-test--make-dated-entry ma)
                   (ora-test--make-dated-entry mb))))))

(ert-deftest ora/cmp-date/uses-earliest-of-deadline-and-scheduled ()
  "When both DEADLINE and SCHEDULED are set, the earlier one wins."
  (ora-test--with-live-org-buffers
      ;; A: scheduled Feb 1, deadline Apr 1 → effective date Feb 1
      ((ma "* Task A\nSCHEDULED: <2026-02-01 Sun>\nDEADLINE: <2026-04-01 Wed>\n")
       ;; B: deadline Mar 1
       (mb "* Task B\nDEADLINE: <2026-03-01 Sun>\n"))
    ;; Feb 1 < Mar 1, so A sorts before B
    (should (= -1 (org-better-agenda-cmp-earliest-date
                   (ora-test--make-dated-entry ma)
                   (ora-test--make-dated-entry mb))))))

(ert-deftest ora/cmp-date/dead-marker-does-not-crash ()
  "A marker whose buffer has been killed must not signal an error."
  (ora-test--with-live-org-buffers
      ((ma "* Task A\nDEADLINE: <2026-04-04 Sat>\n")
       (mb "* Task B\nDEADLINE: <2026-06-01 Mon>\n"))
    ;; Kill A's buffer — ma is now a dead marker
    (kill-buffer (marker-buffer ma))
    ;; A has no resolvable date → treated as undated → B (dated) sorts first
    (should (= 1 (org-better-agenda-cmp-earliest-date
                  (ora-test--make-dated-entry ma)
                  (ora-test--make-dated-entry mb))))))

;;; org-better-agenda-entry-date-info — English

(ert-deftest ora/entry-date-info/deadline-only ()
  (ora-test--with-org-entry "* Task\nDEADLINE: <2026-04-04 Sat>\n"
    (should (equal (org-better-agenda-entry-date-info) "Deadline: 4 April"))))

(ert-deftest ora/entry-date-info/scheduled-only ()
  (ora-test--with-org-entry "* Task\nSCHEDULED: <2026-06-15 Mon>\n"
    (should (equal (org-better-agenda-entry-date-info) "Scheduled: 15 June"))))

(ert-deftest ora/entry-date-info/both ()
  (ora-test--with-org-entry
      "* Task\nDEADLINE: <2026-04-04 Sat> SCHEDULED: <2026-03-01 Sun>\n"
    (should (equal (org-better-agenda-entry-date-info)
                   "Scheduled: 1 March · Deadline: 4 April"))))

(ert-deftest ora/entry-date-info/neither ()
  (ora-test--with-org-entry "* Task\n"
    (should (equal (org-better-agenda-entry-date-info) ""))))

;;; org-better-agenda-entry-date-info — Norwegian

(ert-deftest ora/entry-date-info/norwegian-deadline ()
  "Norwegian locale uses 'Frist' label, ordinal period, and lowercase month names."
  (let ((org-better-agenda-language 'no))
    (ora-test--with-org-entry "* Task\nDEADLINE: <2026-04-04 Sat>\n"
      (should (equal (org-better-agenda-entry-date-info) "Frist: 4. april")))))

(ert-deftest ora/entry-date-info/norwegian-scheduled ()
  (let ((org-better-agenda-language 'no))
    (ora-test--with-org-entry "* Task\nSCHEDULED: <2026-06-15 Mon>\n"
      (should (equal (org-better-agenda-entry-date-info) "Planlagt: 15. juni")))))

(ert-deftest ora/entry-date-info/norwegian-both ()
  (let ((org-better-agenda-language 'no))
    (ora-test--with-org-entry
        "* Task\nDEADLINE: <2026-04-04 Sat> SCHEDULED: <2026-03-01 Sun>\n"
      (should (equal (org-better-agenda-entry-date-info)
                     "Planlagt: 1. mars · Frist: 4. april")))))

;;; org-better-agenda-entry-date-info — German

(ert-deftest ora/entry-date-info/german-deadline ()
  "German locale uses 'Frist' label, ordinal period, and capitalized month names."
  (let ((org-better-agenda-language 'de))
    (ora-test--with-org-entry "* Task\nDEADLINE: <2026-04-04 Sat>\n"
      (should (equal (org-better-agenda-entry-date-info) "Frist: 4. April")))))

(ert-deftest ora/entry-date-info/german-scheduled ()
  (let ((org-better-agenda-language 'de))
    (ora-test--with-org-entry "* Task\nSCHEDULED: <2026-06-15 Mon>\n"
      (should (equal (org-better-agenda-entry-date-info) "Geplant: 15. Juni")))))

(ert-deftest ora/entry-date-info/german-both ()
  (let ((org-better-agenda-language 'de))
    (ora-test--with-org-entry
        "* Task\nDEADLINE: <2026-04-04 Sat> SCHEDULED: <2026-03-01 Sun>\n"
      (should (equal (org-better-agenda-entry-date-info)
                     "Geplant: 1. März · Frist: 4. April")))))

;;; org-better-agenda--str

(ert-deftest ora/str/english-keys ()
  "All expected keys are present for the English locale."
  (let ((org-better-agenda-language 'en))
    (should (equal (org-better-agenda--str 'deadline-label)  "Deadline"))
    (should (equal (org-better-agenda--str 'scheduled-label) "Scheduled"))
    (should (equal (org-better-agenda--str 'must-do-header)  "Must do"))
    (should (equal (org-better-agenda--str 'someday-header)  "When I have time"))
    (should (equal (org-better-agenda--str 'view-title)      "Tasks"))))

(ert-deftest ora/str/norwegian-keys ()
  "All expected keys are present for the Norwegian locale."
  (let ((org-better-agenda-language 'no))
    (should (equal (org-better-agenda--str 'deadline-label)  "Frist"))
    (should (equal (org-better-agenda--str 'scheduled-label) "Planlagt"))
    (should (equal (org-better-agenda--str 'must-do-header)  "Må gjøres"))
    (should (equal (org-better-agenda--str 'someday-header)  "Når jeg har tid"))
    (should (equal (org-better-agenda--str 'view-title)      "Oppgaver"))))

(ert-deftest ora/str/german-keys ()
  "All expected keys are present for the German locale."
  (let ((org-better-agenda-language 'de))
    (should (equal (org-better-agenda--str 'deadline-label)  "Frist"))
    (should (equal (org-better-agenda--str 'scheduled-label) "Geplant"))
    (should (equal (org-better-agenda--str 'must-do-header)  "Zu erledigen"))
    (should (equal (org-better-agenda--str 'someday-header)  "Wenn ich Zeit habe"))
    (should (equal (org-better-agenda--str 'view-title)      "Aufgaben"))))

;;; org-better-agenda-format-date-header
;;
;; Reference date: Wednesday 8 April 2026  → calendar list (4 8 2026)
;; Monday 13 April 2026, ISO week 16       → calendar list (4 13 2026)

(ert-deftest ora/format-date-header/english-weekday ()
  "English: full day and month names, aligned layout."
  (let ((org-better-agenda-language 'en))
    (let ((result (org-better-agenda-format-date-header '(4 8 2026))))
      (should (string-match-p "Wednesday" result))
      (should (string-match-p "April"     result))
      (should (string-match-p "2026"      result)))))

(ert-deftest ora/format-date-header/english-monday-has-week ()
  "English Monday: week number appended."
  (let ((org-better-agenda-language 'en))
    (let ((result (org-better-agenda-format-date-header '(4 13 2026))))
      (should (string-match-p "Monday" result))
      (should (string-match-p "W16"    result)))))

(ert-deftest ora/format-date-header/english-non-monday-no-week ()
  "Non-Monday entries carry no week number."
  (let ((org-better-agenda-language 'en))
    (should (not (string-match-p " W[0-9]"
                                 (org-better-agenda-format-date-header '(4 8 2026)))))))

(ert-deftest ora/format-date-header/norwegian-weekday ()
  "Norwegian: capitalized day name, ordinal period, lowercase month."
  (let ((org-better-agenda-language 'no))
    (let ((result (org-better-agenda-format-date-header '(4 8 2026))))
      (should (string-match-p "Onsdag" result))
      (should (string-match-p "8\\."   result))
      (should (string-match-p "april"  result))
      (should (string-match-p "2026"   result)))))

(ert-deftest ora/format-date-header/norwegian-monday-has-week ()
  "Norwegian Monday: capitalized day name and week number appended."
  (let ((org-better-agenda-language 'no))
    (let ((result (org-better-agenda-format-date-header '(4 13 2026))))
      (should (string-match-p "Mandag" result))
      (should (string-match-p "W16"    result)))))

(ert-deftest ora/format-date-header/norwegian-all-days ()
  "All seven Norwegian day names (capitalized) appear in format-date-header."
  (let ((org-better-agenda-language 'no)
        ;; One known date per day-of-week starting from Sunday 2026-04-05
        (dates '((4 5 2026)   ; Søndag
                 (4 6 2026)   ; Mandag
                 (4 7 2026)   ; Tirsdag
                 (4 8 2026)   ; Onsdag
                 (4 9 2026)   ; Torsdag
                 (4 10 2026)  ; Fredag
                 (4 11 2026)  ; Lørdag
                 ))
        (expected '("Søndag" "Mandag" "Tirsdag" "Onsdag"
                    "Torsdag" "Fredag" "Lørdag")))
    (cl-mapc
     (lambda (date name)
       (should (string-match-p name (org-better-agenda-format-date-header date))))
     dates expected)))

(ert-deftest ora/format-date-header/german-weekday ()
  "German: capitalized day name, ordinal period, capitalized month."
  (let ((org-better-agenda-language 'de))
    (let ((result (org-better-agenda-format-date-header '(4 8 2026))))
      (should (string-match-p "Mittwoch" result))
      (should (string-match-p "8\\."     result))
      (should (string-match-p "April"   result))
      (should (string-match-p "2026"    result)))))

(ert-deftest ora/format-date-header/german-monday-has-week ()
  "German Monday: capitalized day name and week number appended."
  (let ((org-better-agenda-language 'de))
    (let ((result (org-better-agenda-format-date-header '(4 13 2026))))
      (should (string-match-p "Montag" result))
      (should (string-match-p "W16"    result)))))

(provide 'org-better-agenda-test)
;;; org-better-agenda-test.el ends here
