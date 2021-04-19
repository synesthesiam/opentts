;;  ----------------------------------------------------------------  ;;
;;                 Nagoya Institute of Technology and                 ;;
;;                     Carnegie Mellon University                     ;;
;;                         Copyright (c) 2002                         ;;
;;                        All Rights Reserved.                        ;;
;;                                                                    ;;
;;  Permission is hereby granted, free of charge, to use and          ;;
;;  distribute this software and its documentation without            ;;
;;  restriction, including without limitation the rights to use,      ;;
;;  copy, modify, merge, publish, distribute, sublicense, and/or      ;;
;;  sell copies of this work, and to permit persons to whom this      ;;
;;  work is furnished to do so, subject to the following conditions:  ;;
;;                                                                    ;;
;;    1. The code must retain the above copyright notice, this list   ;;
;;       of conditions and the following disclaimer.                  ;;
;;                                                                    ;;
;;    2. Any modifications must be clearly marked as such.            ;;
;;                                                                    ;;
;;    3. Original authors' names are not deleted.                     ;;
;;                                                                    ;;
;;    4. The authors' names are not used to endorse or promote        ;;
;;       products derived from this software without specific prior   ;;
;;       written permission.                                          ;;
;;                                                                    ;;
;;  NAGOYA INSTITUTE OF TECHNOLOGY, CARNEGIE MELLON UNIVERSITY AND    ;;
;;  THE CONTRIBUTORS TO THIS WORK DISCLAIM ALL WARRANTIES WITH        ;;
;;  REGARD TO THIS SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF      ;;
;;  MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL NAGOYA INSTITUTE   ;;
;;  OF TECHNOLOGY, CARNEGIE MELLON UNIVERSITY NOR THE CONTRIBUTORS    ;;
;;  BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR   ;;
;;  ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR        ;;
;;  PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER    ;;
;;  TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR  ;;
;;  PERFORMANCE OF THIS SOFTWARE.                                     ;;
;;                                                                    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;     A voice based on "HTS" HMM-Based Speech Synthesis System.      ;;
;;          Author :  Alan W Black                                    ;;
;;          Date   :  August 2002                                     ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Try to find the directory where the voice is, this may be from
;;; .../festival/lib/voices/ or from the current directory
(if (assoc 'ara_norm_ziad_hts voice-locations)
    (defvar ara_norm_ziad_hts::hts_dir 
      (cdr (assoc 'ara_norm_ziad_hts voice-locations)))
    (defvar ara_norm_ziad_hts::hts_dir (string-append (pwd) "/")))

(defvar ara_norm_ziad::clunits_dir ara_norm_ziad_hts::hts_dir)
(defvar ara_norm_ziad::clunits_loaded nil)

;;; Did we succeed in finding it
(if (not (probe_file (path-append ara_norm_ziad_hts::hts_dir "festvox/")))
    (begin
     (format stderr "ara_norm_ziad_hts::hts: Can't find voice scm files they are not in\n")
     (format stderr "   %s\n" (path-append  ara_norm_ziad_hts::hts_dir "festvox/"))
     (format stderr "   Either the voice isn't linked in Festival library\n")
     (format stderr "   or you are starting festival in the wrong directory\n")
     (error)))

;;;  Add the directory contains general voice stuff to load-path
(set! load-path (cons (path-append ara_norm_ziad_hts::hts_dir "festvox/") 
		      load-path))

(set! hts_data_dir (path-append ara_norm_ziad_hts::hts_dir "hts/"))

(set! hts_feats_list
      (load (path-append hts_data_dir "feat.list") t))

(require 'hts)
(require_module 'hts_engine)

;;; Voice specific parameter are defined in each of the following
;;; files
(require 'ara_norm_ziad_phoneset)
(require 'ara_norm_ziad_tokenizer)
(require 'ara_norm_ziad_tagger)
(require 'ara_norm_ziad_lexicon)
(require 'ara_norm_ziad_phrasing)
(require 'ara_norm_ziad_intonation)
(require 'ara_norm_ziad_duration)
(require 'ara_norm_ziad_f0model)
(require 'ara_norm_ziad_other)
;; ... and others as required


(define (ara_norm_ziad_hts::voice_reset)
  "(ara_norm_ziad_hts::voice_reset)
Reset global variables back to previous voice."
  (ara_norm_ziad::reset_phoneset)
  (ara_norm_ziad::reset_tokenizer)
  (ara_norm_ziad::reset_tagger)
  (ara_norm_ziad::reset_lexicon)
  (ara_norm_ziad::reset_phrasing)
  (ara_norm_ziad::reset_intonation)
  (ara_norm_ziad::reset_duration)
  (ara_norm_ziad::reset_f0model)
  (ara_norm_ziad::reset_other)

  t
)

(set! ara_norm_ziad_hts::hts_feats_list
      (load (path-append hts_data_dir "feat.list") t))

(set! ara_norm_ziad_hts::hts_engine_params
      (list
       (list "-m" (path-append hts_data_dir "ara_norm_ziad_hts.htsvoice"))
       '("-g" 0.0)
       '("-b" 0.0)
       '("-u" 0.5)
       ))

;; This function is called to setup a voice.  It will typically
;; simply call functions that are defined in other files in this directory
;; Sometime these simply set up standard Festival modules othertimes
;; these will be specific to this voice.
;; Feel free to add to this list if your language requires it

(define (voice_ara_norm_ziad_hts)
  "(voice_ara_norm_ziad_hts)
Define voice for limited domain: us."
  ;; *always* required
  (voice_reset)

  ;; Select appropriate phone set
  (ara_norm_ziad::select_phoneset)

  ;; Select appropriate tokenization
  (ara_norm_ziad::select_tokenizer)

  ;; For part of speech tagging
  (ara_norm_ziad::select_tagger)

  (ara_norm_ziad::select_lexicon)
  ;; For hts selection you probably don't want vowel reduction
  ;; the unit selection will do that
  (if (string-equal "americanenglish" (Param.get 'Language))
      (set! postlex_vowel_reduce_cart_tree nil))

  (ara_norm_ziad::select_phrasing)

  (ara_norm_ziad::select_intonation)

  (ara_norm_ziad::select_duration)

  (ara_norm_ziad::select_f0model)

  ;; Waveform synthesis model: hts
  (set! hts_engine_params ara_norm_ziad_hts::hts_engine_params)
  (set! hts_feats_list ara_norm_ziad_hts::hts_feats_list)
  (Parameter.set 'Synth_Method 'HTS)

  ;; This is where you can modify power (and sampling rate) if desired
  (set! after_synth_hooks nil)
;  (set! after_synth_hooks
;      (list
;        (lambda (utt)
;          (utt.wave.rescale utt 2.1))))

  (set! current_voice_reset ara_norm_ziad_hts::voice_reset)

  (set! current-voice 'ara_norm_ziad_hts)
)

(proclaim_voice
 'ara_norm_ziad_hts
 '((language english)
   (gender female)
   (dialect american)
   (description
    "This voice provides an American English female voice using
     HTS.")))

(provide 'ara_norm_ziad_hts)

