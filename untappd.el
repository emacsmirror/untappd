;;; untappd.el --- Display your latest untappd feed -*- lexical-binding: t; -*-

;; Copyright (C) 2021 Matthieu Petiteau

;; Author: Matthieu Petiteau <matt@smallwat3r.com>
;; URL: https://github.com/smallwat3r/untappd.el
;; Package-Requires: ((emacs "26.1") (request "0.3.2"))
;; Version: 0.0.1

;; This file is NOT part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; This package allows you to fetch your latest untappd feed and
;; display the latest information.

;;; Code:

(require 'cl-lib)
(require 'request)

(defcustom untappd-access-token nil
  "Untappd access token."
  :group 'untappd
  :type 'string)

(defvar untappd-feed-api-url "https://api.untappd.com/v4/checkin/recent"
  "Untappd feed API endpoint.")

(defface untappd-rating-icon-face
  '((t :foreground "gold"))
  "The face used on the rating icon."
  :group 'untappd-faces)

(defface untappd-main-element-face
  '((t :weight bold))
  "The face used to display the main elements."
  :group 'untappd-faces)

(defun untappd--format-rating (rating)
  "Format beer RATING."
  (propertize
   (cond ((>= rating 4.5) "●●●●●")
         ((>= rating 4)   "●●●● ")
         ((>= rating 3)   "●●●  ")
         ((>= rating 2)   "●●   ")
         (t               "●    "))
   'face 'untappd-rating-icon-face))

(defun untappd--format-checkin-header (rating beer brewery)
  "Format the checkin header line with the RATING, BEER and BREWERY."
  (format "%s (%s/5) 🍺 %s from %s"
          (untappd--format-rating rating)
          rating
          (propertize (assoc-default 'beer_name beer) 'face 'untappd-main-element-face)
          (propertize (assoc-default 'brewery_name brewery) 'face 'untappd-main-element-face)))

(defun untappd--format-checkin-details (date venue)
  "Format the checking details with the DATE and the VENUE."
  (concat
   date
   (if venue
       (concat " @ " (assoc-default 'venue_name venue)))))

(defun untappd--format-checkin-description (comment user toasts)
  "Format the content with the USER, checkin COMMENT and number of TOASTS.."
  (format "(%s) %s %s (%s): %s"
          (concat (number-to-string (assoc-default 'total_count toasts)) "🍻")
          (assoc-default 'first_name user)
          (assoc-default 'last_name user)
          (propertize (assoc-default 'user_name user) 'face 'untappd-main-element-face)
          (if (or (eq comment nil) (eq comment "")) "-"
            comment)))

(defun untappd--render-feed (data buffer)
  "Render DATA in the untappd BUFFER."
  (switch-to-buffer-other-window buffer)
  (setq buffer-read-only nil)
  (erase-buffer)
  (let* ((items   (assoc-default 'items (assoc-default 'checkins (assoc-default 'response data))))
         (rating  (mapcar (lambda (item) (assoc-default 'rating_score item)) items))
         (comment (mapcar (lambda (item) (assoc-default 'checkin_comment item)) items))
         (date    (mapcar (lambda (item) (assoc-default 'created_at item)) items))
         (user    (mapcar (lambda (item) (assoc-default 'user item)) items))
         (beer    (mapcar (lambda (item) (assoc-default 'beer item)) items))
         (brewery (mapcar (lambda (item) (assoc-default 'brewery item)) items))
         (venue   (mapcar (lambda (item) (assoc-default 'venue item)) items))
         (toasts  (mapcar (lambda (item) (assoc-default 'toasts item)) items)))
    (cl-mapcar (lambda (rating comment date user beer brewery venue toasts)
                 (insert (concat
                          (untappd--format-checkin-header rating beer brewery) "\n"
                          (untappd--format-checkin-details date venue) "\n"
                          (untappd--format-checkin-description comment user toasts) "\n\n")))
               rating comment date user beer brewery venue toasts))
  (goto-char (point-min))
  (setq buffer-read-only t))

(defun untappd--query-feed ()
  "Get recent activity feed data from untappd using the user ACCESS-TOKEN."
  (request (concat untappd-feed-api-url (concat "?access_token=" untappd-access-token))
           :parser 'json-read
           :success
           (cl-function
            (lambda (&key data &allow-other-keys)
              (let ((buffer (get-buffer-create "*untappd*")))
                (untappd--render-feed data buffer))))
           :error
           (cl-function
            (lambda (&rest args &key error-thrown &allow-other-keys)
              (message "An error has occurred while reaching the untappd API: %s"
                       error-thrown)))))

;;;###autoload
(defun untappd-feed ()
  "Get the current feed from your untappd account."
  (interactive)
  (untappd--query-feed))

(provide 'untappd)

;;; untappd.el ends here