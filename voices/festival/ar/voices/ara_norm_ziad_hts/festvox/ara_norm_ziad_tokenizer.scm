;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;                                                                     ;;;
;;;                     Carnegie Mellon University                      ;;;
;;;                  and Alan W Black and Kevin Lenzo                   ;;;
;;;                      Copyright (c) 1998-2000                        ;;;
;;;                        All Rights Reserved.                         ;;;
;;;                                                                     ;;;
;;; Permission is hereby granted, free of charge, to use and distribute ;;;
;;; this software and its documentation without restriction, including  ;;;
;;; without limitation the rights to use, copy, modify, merge, publish, ;;;
;;; distribute, sublicense, and/or sell copies of this work, and to     ;;;
;;; permit persons to whom this work is furnished to do so, subject to  ;;;
;;; the following conditions:                                           ;;;
;;;  1. The code must retain the above copyright notice, this list of   ;;;
;;;     conditions and the following disclaimer.                        ;;;
;;;  2. Any modifications must be clearly marked as such.               ;;;
;;;  3. Original authors' names are not deleted.                        ;;;
;;;  4. The authors' names are not used to endorse or promote products  ;;;
;;;     derived from this software without specific prior written       ;;;
;;;     permission.                                                     ;;;
;;;                                                                     ;;;
;;; CARNEGIE MELLON UNIVERSITY AND THE CONTRIBUTORS TO THIS WORK        ;;;
;;; DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING     ;;;
;;; ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT  ;;;
;;; SHALL CARNEGIE MELLON UNIVERSITY NOR THE CONTRIBUTORS BE LIABLE     ;;;
;;; FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES   ;;;
;;; WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN  ;;;
;;; AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,         ;;;
;;; ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF      ;;;
;;; THIS SOFTWARE.                                                      ;;;
;;;                                                                     ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Tokenizer for norm
;;;
;;;  To share this among voices you need to promote this file to
;;;  to say festival/lib/ara_norm/ so others can use it.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Load any other required files

;; Punctuation for the particular language
(set! ara_norm_ziad::token.punctuation "\"'`.,:;!?(){}[]")
(set! ara_norm_ziad::token.prepunctuation "\"'`({[")
(set! ara_norm_ziad::token.whitespace " \t\n\r")
(set! ara_norm_ziad::token.singlecharsymbols "")

;;; Voice/norm token_to_word rules 
(define (ara_norm_ziad::token_to_words token name)
  "(ara_norm_ziad::token_to_words token name)
Specific token to word rules for the voice ara_norm_ziad.  Returns a list
of words that expand given token with name."
  (cond
   ((string-matches name "[0-9]+")
    (ara_norm::number token name))
   (t ;; when no specific rules apply do the general ones
    (list name))))
 

(define (ara_norm::number token name)
  "(ara_norm::number token name)
Return list of words that pronounce this number in norm."
(arabic_number name)

)

(define (ara_norm_ziad::select_tokenizer)
  "(ara_norm_ziad::select_tokenizer)
Set up tokenizer for norm."
  (Parameter.set 'Language 'ara_norm)
  (set! token.punctuation ara_norm_ziad::token.punctuation)
  (set! token.prepunctuation ara_norm_ziad::token.prepunctuation)
  (set! token.whitespace ara_norm_ziad::token.whitespace)
  (set! token.singlecharsymbols ara_norm_ziad::token.singlecharsymbols)

  (set! token_to_words ara_norm_ziad::token_to_words)
)

(define (ara_norm_ziad::reset_tokenizer)
  "(ara_norm_ziad::reset_tokenizer)
Reset any globals modified for this voice.  Called by 
(ara_norm_ziad::voice_reset)."
  ;; None

  t
)

;;;;;;;;;;;;;;;;;;;;;;;Number;;;;;;;;;;;;;;;;;;;;;;;;;

(define (arabic_number name)

"(arabic_number name)
Convert a string of digits into a list of words saying the number."
  (if (string-matches name "0") 
	(list "صِفرٌ")
;	 (if (string-matches name "۲") (define s (number->string (2)))
	;(format stderr "%s\n" name)

	(arabic_number_from_digits (symbolexplode name))

;)
)
); end define

(define (just_zeros digits)
"(just_zeros digits)
If this only contains 0s then we just do something different."
 (cond
  ((not digits) t)
  ((string-equal "0" (car digits))
   (just_zeros (cdr digits)))
  (t nil)))

(define (arabic_number_from_digits digits)
  "(arabic_number_from_digits digits)
Takes a list of digits and converts it to a list of words
saying the number."

(let ((l (length digits)))
    (cond
     ((equal? l 0)
      nil)
     ((string-equal (car digits) "0")
      (arabic_number_from_digits (cdr digits)))
     ((equal? l 1);; single digit
      (cond 
 ;      ((equal? (item.feat token "p.digits") "۲") (list "إِثْنَانِ"))

       ((string-equal (car digits) "0") (list "صِفرٌ"))
       ((string-equal (car digits) "1") (list "وَاحِدٌ"))
       ((string-equal (car digits) "2") (list "إِثْنَانِ"))
       ((string-equal (car digits) "3") (list "ثَلَاثَةٌ"))
       ((string-equal (car digits) "4") (list "أَرْبَعَةٌ"))
       ((string-equal (car digits) "5") (list "خَمْسَةٌ"))
       ((string-equal (car digits) "6") (list "سِتَّةٌ"))
       ((string-equal (car digits) "7") (list "سَبْعَةٌ"))
       ((string-equal (car digits) "8") (list "ثَمَانِيَةٌ"))
       ((string-equal (car digits) "9") (list "تِسْعَةٌ"))

       (t (list "رَقْمٌ"))));; else
     ((equal? l 2);; less than 100
      (cond
       ((string-equal (car digits) "0");; 0x
	(arabic_number_from_digits (cdr digits)))
     
       ((string-equal (car digits) "1");; 1x
	(cond
	 ((string-equal (car (cdr digits)) "0") (list "عَشَرَةٌ"))
	 ((string-equal (car (cdr digits)) "1") (list "إِحدَا عَشَر"))
	 ((string-equal (car (cdr digits)) "2") (list "إِثْنَا عَشَر"))
	 ((string-equal (car (cdr digits)) "3") (list "ثَلَاثَةَ عَشَر"))
	 ((string-equal (car (cdr digits)) "4") (list "أَرْبَعَةَ عَشَر"))
	 ((string-equal (car (cdr digits)) "5") (list "خَمْسَةَ عَشَر"))
	((string-equal (car (cdr digits)) "6") (list "سِتَّةَ عَشَر"))
	((string-equal (car (cdr digits)) "7") (list "سَبْعَةَ عَشَر"))
	((string-equal (car (cdr digits)) "8") (list "ثَمَانِيَةَ عَشَر"))
	((string-equal (car (cdr digits)) "9") (list "تِسْعَةَ عَشَر"))
	 (t (list "رَقْمٌ"))));; else
     
       ((string-equal (car digits) "2");; 2x
	;(if (string-equal (car (cdr digits)) "0") 
	 ;   (list "عِشْرُون")
	  ;  (cons (arabic_number_from_digits (cdr digits)) "وَ عِشْرُون ")))
	(cond
	 ((string-equal (car (cdr digits)) "0") (list "عِشْرُون"))
	 ((string-equal (car (cdr digits)) "1") (list "وَاحِدٌ وَ عِشْرُون"))
	 ((string-equal (car (cdr digits)) "2") (list "إِثْنَانِ وَ عِشْرُون"))
       	 ((string-equal (car (cdr digits)) "3") (list "ثَلَاثَةٌ وَ عِشْرُون"))
         ((string-equal (car (cdr digits)) "4") (list "أَرْبَعَةٌ وَ عِشْرُون"))
         ((string-equal (car (cdr digits)) "5") (list "خَمْسَةٌ وَ عِشْرُون"))
         ((string-equal (car (cdr digits)) "6") (list "سِتَّةٌ وَ عِشْرُون"))
         ((string-equal (car (cdr digits)) "7") (list "سَبْعَةٌ وَ عِشْرُون"))
         ((string-equal (car (cdr digits)) "8") (list "ثَمَانِيَةٌ وَ عِشْرُون"))
         ((string-equal (car (cdr digits)) "9") (list "تِسْعَةٌ وَ عِشْرُون"))
	 (t (list "رَقْمٌ"))));; else

       ((string-equal (car digits) "3");; 3x
	;(if (string-equal (car (cdr digits)) "0") 
	 ;   (list "ثَلَاثُون")
	  ;  (cons (arabic_number_from_digits (cdr digits)) "وَ ثَلَاثُون ")))
	 (cond
	 ((string-equal (car (cdr digits)) "0") (list "ثَلَاثُون"))
	 ((string-equal (car (cdr digits)) "1") (list "وَاحِدٌ وَ ثَلَاثُون"))
	 ((string-equal (car (cdr digits)) "2") (list "إِثْنَانِ وَ ثَلَاثُون"))
       	 ((string-equal (car (cdr digits)) "3") (list "ثَلَاثَةٌ وَ ثَلَاثُون"))
         ((string-equal (car (cdr digits)) "4") (list "أَرْبَعَةٌ وَ ثَلَاثُون"))
         ((string-equal (car (cdr digits)) "5") (list "خَمْسَةٌ وَ ثَلَاثُون"))
         ((string-equal (car (cdr digits)) "6") (list "سِتَّةٌ وَ ثَلَاثُون"))
         ((string-equal (car (cdr digits)) "7") (list "سَبْعَةٌ وَ ثَلَاثُون"))
         ((string-equal (car (cdr digits)) "8") (list "ثَمَانِيَةٌ وَ ثَلَاثُون"))
         ((string-equal (car (cdr digits)) "9") (list "تِسْعَةٌ وَ ثَلَاثُون"))
	 (t (list "رَقْمٌ"))));; else

       ((string-equal (car digits) "4");; 4x
	;(if (string-equal (car (cdr digits)) "0") 
	 ;   (list "أَرْبَعُون")
	  ;  (cons (arabic_number_from_digits (cdr digits)) "وَ أَرْبَعُون ")))
	 (cond
	 ((string-equal (car (cdr digits)) "0") (list "أَرْبَعُون"))
	 ((string-equal (car (cdr digits)) "1") (list "وَاحِدٌ وَ أَرْبَعُون"))
	 ((string-equal (car (cdr digits)) "2") (list "إِثْنَانِ وَ أَرْبَعُون"))
       	 ((string-equal (car (cdr digits)) "3") (list "ثَلَاثَةٌ وَ أَرْبَعُون"))
         ((string-equal (car (cdr digits)) "4") (list "أَرْبَعَةٌ وَ أَرْبَعُون"))
         ((string-equal (car (cdr digits)) "5") (list "خَمْسَةٌ وَ أَرْبَعُون"))
         ((string-equal (car (cdr digits)) "6") (list "سِتَّةٌ وَ أَرْبَعُون"))
         ((string-equal (car (cdr digits)) "7") (list "سَبْعَةٌ وَ أَرْبَعُون"))
         ((string-equal (car (cdr digits)) "8") (list "ثَمَانِيَةٌ وَ أَرْبَعُون"))
         ((string-equal (car (cdr digits)) "9") (list "تِسْعَةٌ وَ أَرْبَعُون"))
	 (t (list "رَقْمٌ"))));; else

       ((string-equal (car digits) "5");; 5x
	;(if (string-equal (car (cdr digits)) "0") 
	 ;   (list "خَمسُون")
	  ;  (cons (arabic_number_from_digits (cdr digits)) "وَ خَمسُون ")))
	 (cond
	 ((string-equal (car (cdr digits)) "0") (list "خَمسُون"))
	 ((string-equal (car (cdr digits)) "1") (list "وَاحِدٌ وَ خَمسُون"))
	 ((string-equal (car (cdr digits)) "2") (list "إِثْنَانِ وَ خَمسُون"))
       	 ((string-equal (car (cdr digits)) "3") (list "ثَلَاثَةٌ وَ خَمسُون"))
         ((string-equal (car (cdr digits)) "4") (list "أَرْبَعَةٌ وَ خَمسُون"))
         ((string-equal (car (cdr digits)) "5") (list "خَمْسَةٌ وَ خَمسُون"))
         ((string-equal (car (cdr digits)) "6") (list "سِتَّةٌ وَ خَمسُون"))
         ((string-equal (car (cdr digits)) "7") (list "سَبْعَةٌ وَ خَمسُون"))
         ((string-equal (car (cdr digits)) "8") (list "ثَمَانِيَةٌ وَ خَمسُون"))
         ((string-equal (car (cdr digits)) "9") (list "تِسْعَةٌ وَ خَمسُون"))
	 (t (list "رَقْمٌ"))));; else

       ((string-equal (car digits) "6");; 6x
	;(if (string-equal (car (cdr digits)) "0") 
	 ;   (list "سِتُّون")
	  ;  (cons (arabic_number_from_digits (cdr digits)) "وَ سِتُّون ")))
	 (cond
	 ((string-equal (car (cdr digits)) "0") (list "سِتُّون"))
	 ((string-equal (car (cdr digits)) "1") (list "وَاحِدٌ وَ سِتُّون"))
	 ((string-equal (car (cdr digits)) "2") (list "إِثْنَانِ وَ سِتُّون"))
       	 ((string-equal (car (cdr digits)) "3") (list "ثَلَاثَةٌ وَ سِتُّون"))
         ((string-equal (car (cdr digits)) "4") (list "أَرْبَعَةٌ وَ سِتُّون"))
         ((string-equal (car (cdr digits)) "5") (list "خَمْسَةٌ وَ سِتُّون"))
         ((string-equal (car (cdr digits)) "6") (list "سِتَّةٌ وَ سِتُّون"))
         ((string-equal (car (cdr digits)) "7") (list "سَبْعَةٌ وَ سِتُّون"))
         ((string-equal (car (cdr digits)) "8") (list "ثَمَانِيَةٌ وَ سِتُّون"))
         ((string-equal (car (cdr digits)) "9") (list "تِسْعَةٌ وَ سِتُّون"))
	 (t (list "رَقْمٌ"))));; else

       ((string-equal (car digits) "7");; 7x
	;(if (string-equal (car (cdr digits)) "0") 
	 ;   (list "سَبْعُون")
	  ;  (cons (arabic_number_from_digits (cdr digits)) "وَ سَبْعُون ")))
	 (cond
	 ((string-equal (car (cdr digits)) "0") (list "سَبْعُون"))
	 ((string-equal (car (cdr digits)) "1") (list "وَاحِدٌ وَ سَبْعُون"))
	 ((string-equal (car (cdr digits)) "2") (list "إِثْنَانِ وَ سَبْعُون"))
       	 ((string-equal (car (cdr digits)) "3") (list "ثَلَاثَةٌ وَ سَبْعُون"))
         ((string-equal (car (cdr digits)) "4") (list "أَرْبَعَةٌ وَ سَبْعُون"))
         ((string-equal (car (cdr digits)) "5") (list "خَمْسَةٌ وَ سَبْعُون"))
         ((string-equal (car (cdr digits)) "6") (list "سِتَّةٌ وَ سَبْعُون"))
         ((string-equal (car (cdr digits)) "7") (list "سَبْعَةٌ وَ سَبْعُون"))
         ((string-equal (car (cdr digits)) "8") (list "ثَمَانِيَةٌ وَ سَبْعُون"))
         ((string-equal (car (cdr digits)) "9") (list "تِسْعَةٌ وَ سَبْعُون"))
	 (t (list "رَقْمٌ"))));; else

       ((string-equal (car digits) "8");; 8x
	;(if (string-equal (car (cdr digits)) "0") 
	;    (list "ثَمَانُون")
	 ;   (cons (arabic_number_from_digits (cdr digits)) "وَ ثَمَانُون ")))
	 (cond
	 ((string-equal (car (cdr digits)) "0") (list "ثَمَانُون"))
	 ((string-equal (car (cdr digits)) "1") (list "وَاحِدٌ وَ ثَمَانُون"))
	 ((string-equal (car (cdr digits)) "2") (list "إِثْنَانِ وَ ثَمَانُون"))
       	 ((string-equal (car (cdr digits)) "3") (list "ثَلَاثَةٌ وَ ثَمَانُون"))
         ((string-equal (car (cdr digits)) "4") (list "أَرْبَعَةٌ وَ ثَمَانُون"))
         ((string-equal (car (cdr digits)) "5") (list "خَمْسَةٌ وَ ثَمَانُون"))
         ((string-equal (car (cdr digits)) "6") (list "سِتَّةٌ وَ ثَمَانُون"))
         ((string-equal (car (cdr digits)) "7") (list "سَبْعَةٌ وَ ثَمَانُون"))
         ((string-equal (car (cdr digits)) "8") (list "ثَمَانِيَةٌ وَ ثَمَانُون"))
         ((string-equal (car (cdr digits)) "9") (list "تِسْعَةٌ وَ ثَمَانُون"))
	 (t (list "رَقْمٌ"))));; else

       ((string-equal (car digits) "9");; 9x
	;(if (string-equal (car (cdr digits)) "0") 
	 ;   (list "تِسْعُون")
	  ;  (cons (arabic_number_from_digits (cdr digits)) "وَ تِسْعُون ")))
	 (cond
	 ((string-equal (car (cdr digits)) "0") (list "تِسْعُون"))
	 ((string-equal (car (cdr digits)) "1") (list "وَاحِدٌ وَ تِسْعُون"))
	 ((string-equal (car (cdr digits)) "2") (list "إِثْنَانِ وَ تِسْعُون"))
       	 ((string-equal (car (cdr digits)) "3") (list "ثَلَاثَةٌ وَ تِسْعُون"))
         ((string-equal (car (cdr digits)) "4") (list "أَرْبَعَةٌ وَ تِسْعُون"))
         ((string-equal (car (cdr digits)) "5") (list "خَمْسَةٌ وَ تِسْعُون"))
         ((string-equal (car (cdr digits)) "6") (list "سِتَّةٌ وَ تِسْعُون"))
         ((string-equal (car (cdr digits)) "7") (list "سَبْعَةٌ وَ تِسْعُون"))
         ((string-equal (car (cdr digits)) "8") (list "ثَمَانِيَةٌ وَ تِسْعُون"))
         ((string-equal (car (cdr digits)) "9") (list "تِسْعَةٌ وَ تِسْعُون"))
	 (t (list "رَقْمٌ"))));; else

       ))

     ((equal? l 3);; in the hundreds
      (cond 
     
       ((string-equal (car digits) "1");; 1xx
	(if (just_zeros (cdr digits)) (list "مِئَةٌ")
	    (cons " مِئَةٌ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "2");; 2xx
	(if (just_zeros (cdr digits)) (list "مِئَتَانِ")
	    (cons " مِئَتَانِ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "3");; 3xx
	(if (just_zeros (cdr digits)) (list "ثَلَاثُمِئَةٍ")
	    (cons " ثَلَاثُمِئَةٍ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "4");; 4xx
	(if (just_zeros (cdr digits)) (list "أَرْبَعُمِئَةٍ")
	    (cons " أَرْبَعُمِئَةٍ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "5");; 5xx
	(if (just_zeros (cdr digits)) (list "خَمْسُمِئَةٍ")
	    (cons " خَمْسُمِئَةٍ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "6");; 6xx
	(if (just_zeros (cdr digits)) (list "سِتُّمِئَةٍ")
	    (cons " سِتُّمِئَةٍ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "7");; 7xx
	(if (just_zeros (cdr digits)) (list "سَبْعُمِئَةٍ")
	    (cons " سَبْعُمِئَةٍ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "8");; 8xx
	(if (just_zeros (cdr digits)) (list "ثَمَانُمِئَةٍ")
	    (cons " ثَمَانُمِئَةٍ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "9");; 9xx
	(if (just_zeros (cdr digits)) (list "تِسْعُمِئَةٍ")
	    (cons "تِسْعُمِئَةٍ وَ" (arabic_number_from_digits (cdr digits)))))

       ))

     ((equal? l 4);; in the hundreds
      (cond 
     
       ((string-equal (car digits) "1");; 1xxx
	(if (just_zeros (cdr digits)) (list "أَلفٌ")
	    (cons " أَلفٌ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "2");; 2xxx
	(if (just_zeros (cdr digits)) (list "أَلفَانِ")
	    (cons " أَلفَانِ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "3");; 3xxx
	(if (just_zeros (cdr digits)) (list "ثَلَاثَةُ آلَافٍ")
	    (cons " ثَلَاثَةُ آلَافٍ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "4");; 4xxx
	(if (just_zeros (cdr digits)) (list "أَربَعَةُ آلَافٍ")
	    (cons " أَربَعَةُ آلَافٍ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "5");; 5xxx
	(if (just_zeros (cdr digits)) (list "خَمسَةُ آلَافٍ")
	    (cons " خَمسَةُ آلَافٍ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "6");; 6xxx
	(if (just_zeros (cdr digits)) (list "سِتَّةُ آلَافٍ")
	    (cons " سِتَّةُ آلَافٍ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "7");; 7xxx
	(if (just_zeros (cdr digits)) (list "سَبعَةُ آلَافٍ")
	    (cons " سَبعَةُ آلَافٍ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "8");; 8xxx
	(if (just_zeros (cdr digits)) (list "ثَمَانِيَةُ آلَافٍ")
	    (cons " ثَمَانِيَةُ آلَافٍ وَ" (arabic_number_from_digits (cdr digits)))))

	((string-equal (car digits) "9");; 9xxx
	(if (just_zeros (cdr digits)) (list "تِسعَةُ آلَافٍ")
	    (cons " تِسعَةُ آلَافٍ وَ" (arabic_number_from_digits (cdr digits)))))

       ))

	((equal? l 5);; in the hundreds
		 (cond
	       ((string-equal (car digits) "0");; 0x
		(arabic_number_from_digits (cdr digits)))
	     
	       ((string-equal (car digits) "1");; 1xxxx
		(cond

		 ((string-equal (car (cdr digits)) "0");;10xxx 
			(if (just_zeros (cdr (cdr digits))) (list "عَشَرَةُ آلَافٍ")
		        (cons " عَشَرَةُ آلَافٍ وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "1");;11xxx 
			(if (just_zeros (cdr (cdr digits))) (list "إِحدَا عَشَرَ أَلفًا")
		        (cons " إِحدَا عَشَرَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
			
		 ((string-equal (car (cdr digits)) "2");;12xxx 
			(if (just_zeros (cdr (cdr digits))) (list "إِثْنَا عَشَرَ أَلفًا")
		        (cons " إِثْنَا عَشَرَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "3");;13xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَلَاثَةَ عَشَرَ أَلفًا")
		        (cons " ثَلَاثَةَ عَشَرَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "4");;14xxx 
			(if (just_zeros (cdr (cdr digits))) (list "أَرْبَعَةَ عَشَرَ أَلفًا")
		        (cons " أَرْبَعَةَ عَشَرَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "5");;15xxx 
			(if (just_zeros (cdr (cdr digits))) (list "خَمْسَةَ عَشَرَ أَلفًا")
		        (cons " خَمْسَةَ عَشَرَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "6");;16xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سِتَّةَ عَشَرَ أَلفًا")
		        (cons " سِتَّةَ عَشَرَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "7");;17xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سَبْعَةَ عَشَرَ أَلفًا")
		        (cons " سَبْعَةَ عَشَرَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "8");;18xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَمَانِيَةَ عَشَرَ أَلفًا")
		        (cons " ثَمَانِيَةَ عَشَرَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "9");;19xxx 
			(if (just_zeros (cdr (cdr digits))) (list "تِسْعَةَ عَشَرَ أَلفًا")
		        (cons " تِسْعَةَ عَشَرَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
		 (t (list "رَقْمٌ"))));; else

	       ((string-equal (car digits) "2");; 2xxxx
		(cond

		 ((string-equal (car (cdr digits)) "0");;20xxx 
			(if (just_zeros (cdr (cdr digits))) (list "عِشرُونَ أَلفًا")
		        (cons " عِشرُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "1");;21xxx 
			(if (just_zeros (cdr (cdr digits))) (list "وَاحِدٌ وَ عِشْرُونَ أَلفًا")
		        (cons " وَاحِدٌ وَ عِشْرُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
			
		 ((string-equal (car (cdr digits)) "2");;22xxx 
			(if (just_zeros (cdr (cdr digits))) (list "إِثْنَانِ وَ عِشْرُونَ أَلفًا")
		        (cons " إِثْنَانِ وَ عِشْرُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "3");;23xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَلَاثَةٌ وَ عِشْرُونَ أَلفًا")
		        (cons " ثَلَاثَةٌ وَ عِشْرُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "4");;24xxx 
			(if (just_zeros (cdr (cdr digits))) (list "أَرْبَعَةٌ وَ عِشْرُونَ أَلفًا")
		        (cons " أَرْبَعَةٌ وَ عِشْرُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "5");;25xxx 
			(if (just_zeros (cdr (cdr digits))) (list "خَمْسَةٌ وَ عِشْرُونَ أَلفًا")
		        (cons " خَمْسَةٌ وَ عِشْرُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "6");;26xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سِتَّةٌ وَ عِشْرُونَ أَلفًا")
		        (cons " سِتَّةٌ وَ عِشْرُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "7");;27xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سَبْعَةٌ وَ عِشْرُونَ أَلفًا")
		        (cons " سَبْعَةٌ وَ عِشْرُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "8");;28xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَمَانِيَةٌ وَ عِشْرُونَ أَلفًا")
		        (cons " ثَمَانِيَةٌ وَ عِشْرُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "9");;29xxx 
			(if (just_zeros (cdr (cdr digits))) (list "تِسْعَةٌ وَ عِشْرُونَ أَلفًا")
		        (cons " تِسْعَةٌ وَ عِشْرُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
		 (t (list "رَقْمٌ"))));; else

	       ((string-equal (car digits) "3");; 3xxxx
		(cond

		 ((string-equal (car (cdr digits)) "0");;30xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَلَاثُونَ أَلفًا")
		        (cons " ثَلَاثُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "1");;31xxx 
			(if (just_zeros (cdr (cdr digits))) (list "وَاحِدٌ وَ ثَلَاثُونَ أَلفًا")
		        (cons " وَاحِدٌ وَ ثَلَاثُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
			
		 ((string-equal (car (cdr digits)) "2");;32xxx 
			(if (just_zeros (cdr (cdr digits))) (list "إِثْنَانِ وَ ثَلَاثُونَ أَلفًا")
		        (cons " إِثْنَانِ وَ ثَلَاثُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "3");;33xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَلَاثَةٌ وَ ثَلَاثُونَ أَلفًا")
		        (cons " ثَلَاثَةٌ وَ ثَلَاثُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "4");;34xxx 
			(if (just_zeros (cdr (cdr digits))) (list "أَرْبَعَةٌ وَ ثَلَاثُونَ أَلفًا")
		        (cons " أَرْبَعَةٌ وَ ثَلَاثُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "5");;35xxx 
			(if (just_zeros (cdr (cdr digits))) (list "خَمْسَةٌ وَ ثَلَاثُونَ أَلفًا")
		        (cons " خَمْسَةٌ وَ ثَلَاثُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "6");;36xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سِتَّةٌ وَ ثَلَاثُونَ أَلفًا")
		        (cons " سِتَّةٌ وَ ثَلَاثُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "7");;37xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سَبْعَةٌ وَ ثَلَاثُونَ أَلفًا")
		        (cons " سَبْعَةٌ وَ ثَلَاثُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "8");;38xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَمَانِيَةٌ وَ ثَلَاثُونَ أَلفًا")
		        (cons " ثَمَانِيَةٌ وَ ثَلَاثُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "9");;39xxx 
			(if (just_zeros (cdr (cdr digits))) (list "تِسْعَةٌ وَ ثَلَاثُونَ أَلفًا")
		        (cons " تِسْعَةٌ وَ ثَلَاثُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
		 (t (list "رَقْمٌ"))));; else

	       ((string-equal (car digits) "4");;4xxxx
		(cond

		 ((string-equal (car (cdr digits)) "0");;40xxx 
			(if (just_zeros (cdr (cdr digits))) (list "أَرْبَعُونَ أَلفًا")
		        (cons " أَرْبَعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "1");;41xxx 
			(if (just_zeros (cdr (cdr digits))) (list "وَاحِدٌ وَ أَرْبَعُونَ أَلفًا")
		        (cons " وَاحِدٌ وَ أَرْبَعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
			
		 ((string-equal (car (cdr digits)) "2");;42xxx 
			(if (just_zeros (cdr (cdr digits))) (list "إِثْنَانِ وَ أَرْبَعُونَ أَلفًا")
		        (cons " إِثْنَانِ وَ أَرْبَعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "3");;43xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَلَاثَةٌ وَ أَرْبَعُونَ أَلفًا")
		        (cons " ثَلَاثَةٌ وَ أَرْبَعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "4");;44xxx 
			(if (just_zeros (cdr (cdr digits))) (list "أَرْبَعَةٌ وَ أَرْبَعُونَ أَلفًا")
		        (cons " أَرْبَعَةٌ وَ أَرْبَعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "5");;45xxx 
			(if (just_zeros (cdr (cdr digits))) (list "خَمْسَةٌ وَ أَرْبَعُونَ أَلفًا")
		        (cons " خَمْسَةٌ وَ أَرْبَعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "6");;46xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سِتَّةٌ وَ أَرْبَعُونَ أَلفًا")
		        (cons " سِتَّةٌ وَ أَرْبَعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "7");;47xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سَبْعَةٌ وَ أَرْبَعُونَ أَلفًا")
		        (cons " سَبْعَةٌ وَ أَرْبَعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "8");;48xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَمَانِيَةٌ وَ أَرْبَعُونَ أَلفًا")
		        (cons " ثَمَانِيَةٌ وَ أَرْبَعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "9");;49xxx 
			(if (just_zeros (cdr (cdr digits))) (list "تِسْعَةٌ وَ أَرْبَعُونَ أَلفًا")
		        (cons " تِسْعَةٌ وَ أَرْبَعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
		 (t (list "رَقْمٌ"))));; else

	       ((string-equal (car digits) "5");;5xxxx
		(cond

		 ((string-equal (car (cdr digits)) "0");;50xxx 
			(if (just_zeros (cdr (cdr digits))) (list "خَمسُونَ أَلفًا")
		        (cons " خَمسُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "1");;51xxx 
			(if (just_zeros (cdr (cdr digits))) (list "وَاحِدٌ وَ خَمسُونَ أَلفًا")
		        (cons " وَاحِدٌ وَ خَمسُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
			
		 ((string-equal (car (cdr digits)) "2");;52xxx 
			(if (just_zeros (cdr (cdr digits))) (list "إِثْنَانِ وَ خَمسُونَ أَلفًا")
		        (cons " إِثْنَانِ وَ خَمسُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "3");;53xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَلَاثَةٌ وَ خَمسُونَ أَلفًا")
		        (cons " ثَلَاثَةٌ وَ خَمسُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "4");;54xxx 
			(if (just_zeros (cdr (cdr digits))) (list "أَرْبَعَةٌ وَ خَمسُونَ أَلفًا")
		        (cons " أَرْبَعَةٌ وَ خَمسُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "5");;55xxx 
			(if (just_zeros (cdr (cdr digits))) (list "خَمْسَةٌ وَ خَمسُونَ أَلفًا")
		        (cons " خَمْسَةٌ وَ خَمسُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "6");;56xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سِتَّةٌ وَ خَمسُونَ أَلفًا")
		        (cons " سِتَّةٌ وَ خَمسُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "7");;57xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سَبْعَةٌ وَ خَمسُونَ أَلفًا")
		        (cons " سَبْعَةٌ وَ خَمسُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "8");;58xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَمَانِيَةٌ وَ خَمسُونَ أَلفًا")
		        (cons " ثَمَانِيَةٌ وَ خَمسُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "9");;59xxx 
			(if (just_zeros (cdr (cdr digits))) (list "تِسْعَةٌ وَ خَمسُونَ أَلفًا")
		        (cons " تِسْعَةٌ وَ خَمسُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
		 (t (list "رَقْمٌ"))));; else

	       ((string-equal (car digits) "6");;6xxxx
		(cond

		 ((string-equal (car (cdr digits)) "0");;60xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سِتُّونَ أَلفًا")
		        (cons " سِتُّونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "1");;61xxx 
			(if (just_zeros (cdr (cdr digits))) (list "وَاحِدٌ وَ سِتُّونَ أَلفًا")
		        (cons " وَاحِدٌ وَ سِتُّونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
			
		 ((string-equal (car (cdr digits)) "2");;62xxx 
			(if (just_zeros (cdr (cdr digits))) (list "إِثْنَانِ وَ سِتُّونَ أَلفًا")
		        (cons " إِثْنَانِ وَ سِتُّونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "3");;63xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَلَاثَةٌ وَ سِتُّونَ أَلفًا")
		        (cons " ثَلَاثَةٌ وَ سِتُّونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "4");;64xxx 
			(if (just_zeros (cdr (cdr digits))) (list "أَرْبَعَةٌ وَ سِتُّونَ أَلفًا")
		        (cons " أَرْبَعَةٌ وَ سِتُّونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "5");;65xxx 
			(if (just_zeros (cdr (cdr digits))) (list "خَمْسَةٌ وَ سِتُّونَ أَلفًا")
		        (cons " خَمْسَةٌ وَ سِتُّونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "6");;66xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سِتَّةٌ وَ سِتُّونَ أَلفًا")
		        (cons " سِتَّةٌ وَ سِتُّونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "7");;67xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سَبْعَةٌ وَ سِتُّونَ أَلفًا")
		        (cons " سَبْعَةٌ وَ سِتُّونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "8");;68xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَمَانِيَةٌ وَ سِتُّونَ أَلفًا")
		        (cons " ثَمَانِيَةٌ وَ سِتُّونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "9");;69xxx 
			(if (just_zeros (cdr (cdr digits))) (list "تِسْعَةٌ وَ سِتُّونَ أَلفًا")
		        (cons " تِسْعَةٌ وَ سِتُّونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
		 (t (list "رَقْمٌ"))));; else

	       ((string-equal (car digits) "7");;7xxxx
		(cond

		 ((string-equal (car (cdr digits)) "0");;70xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سَبْعُونَ أَلفًا")
		        (cons " سَبْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "1");;71xxx 
			(if (just_zeros (cdr (cdr digits))) (list "وَاحِدٌ وَ سَبْعُونَ أَلفًا")
		        (cons " وَاحِدٌ وَ سَبْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
			
		 ((string-equal (car (cdr digits)) "2");;72xxx 
			(if (just_zeros (cdr (cdr digits))) (list "إِثْنَانِ وَ سَبْعُونَ أَلفًا")
		        (cons " إِثْنَانِ وَ سَبْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "3");;73xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَلَاثَةٌ وَ سَبْعُونَ أَلفًا")
		        (cons " ثَلَاثَةٌ وَ سَبْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "4");;74xxx 
			(if (just_zeros (cdr (cdr digits))) (list "أَرْبَعَةٌ وَ سَبْعُونَ أَلفًا")
		        (cons " أَرْبَعَةٌ وَ سَبْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "5");;75xxx 
			(if (just_zeros (cdr (cdr digits))) (list "خَمْسَةٌ وَ سَبْعُونَ أَلفًا")
		        (cons " خَمْسَةٌ وَ سَبْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "6");;76xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سِتَّةٌ وَ سَبْعُونَ أَلفًا")
		        (cons " سِتَّةٌ وَ سَبْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "7");;77xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سَبْعَةٌ وَ سَبْعُونَ أَلفًا")
		        (cons " سَبْعَةٌ وَ سَبْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "8");;78xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَمَانِيَةٌ وَ سَبْعُونَ أَلفًا")
		        (cons " ثَمَانِيَةٌ وَ سَبْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "9");;79xxx 
			(if (just_zeros (cdr (cdr digits))) (list "تِسْعَةٌ وَ سَبْعُونَ أَلفًا")
		        (cons " تِسْعَةٌ وَ سَبْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
		 (t (list "رَقْمٌ"))));; else

	       ((string-equal (car digits) "8");;8xxxx
		(cond

		 ((string-equal (car (cdr digits)) "0");;80xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَمَانُونَ أَلفًا")
		        (cons " ثَمَانُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "1");;81xxx 
			(if (just_zeros (cdr (cdr digits))) (list "وَاحِدٌ وَ ثَمَانُونَ أَلفًا")
		        (cons " وَاحِدٌ وَ ثَمَانُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
			
		 ((string-equal (car (cdr digits)) "2");;82xxx 
			(if (just_zeros (cdr (cdr digits))) (list "إِثْنَانِ وَ ثَمَانُونَ أَلفًا")
		        (cons " إِثْنَانِ وَ ثَمَانُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "3");;83xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَلَاثَةٌ وَ ثَمَانُونَ أَلفًا")
		        (cons " ثَلَاثَةٌ وَ ثَمَانُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "4");;84xxx 
			(if (just_zeros (cdr (cdr digits))) (list "أَرْبَعَةٌ وَ ثَمَانُونَ أَلفًا")
		        (cons " أَرْبَعَةٌ وَ ثَمَانُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "5");;85xxx 
			(if (just_zeros (cdr (cdr digits))) (list "خَمْسَةٌ وَ ثَمَانُونَ أَلفًا")
		        (cons " خَمْسَةٌ وَ ثَمَانُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "6");;86xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سِتَّةٌ وَ ثَمَانُونَ أَلفًا")
		        (cons " سِتَّةٌ وَ ثَمَانُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "7");;87xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سَبْعَةٌ وَ ثَمَانُونَ أَلفًا")
		        (cons " سَبْعَةٌ وَ ثَمَانُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "8");;88xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَمَانِيَةٌ وَ ثَمَانُونَ أَلفًا")
		        (cons " ثَمَانِيَةٌ وَ ثَمَانُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "9");;89xxx 
			(if (just_zeros (cdr (cdr digits))) (list "تِسْعَةٌ وَ ثَمَانُونَ أَلفًا")
		        (cons " تِسْعَةٌ وَ ثَمَانُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
		 (t (list "رَقْمٌ"))));; else

	       ((string-equal (car digits) "9");;9xxxx
		(cond

		 ((string-equal (car (cdr digits)) "0");;90xxx 
			(if (just_zeros (cdr (cdr digits))) (list "تِسْعُونَ أَلفًا")
		        (cons " تِسْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "1");;91xxx 
			(if (just_zeros (cdr (cdr digits))) (list "وَاحِدٌ وَ تِسْعُونَ أَلفًا")
		        (cons " وَاحِدٌ وَ تِسْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
			
		 ((string-equal (car (cdr digits)) "2");;92xxx 
			(if (just_zeros (cdr (cdr digits))) (list "إِثْنَانِ وَ تِسْعُونَ أَلفًا")
		        (cons " إِثْنَانِ وَ تِسْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "3");;93xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَلَاثَةٌ وَ تِسْعُونَ أَلفًا")
		        (cons " ثَلَاثَةٌ وَ تِسْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "4");;94xxx 
			(if (just_zeros (cdr (cdr digits))) (list "أَرْبَعَةٌ وَ تِسْعُونَ أَلفًا")
		        (cons " أَرْبَعَةٌ وَ تِسْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "5");;95xxx 
			(if (just_zeros (cdr (cdr digits))) (list "خَمْسَةٌ وَ تِسْعُونَ أَلفًا")
		        (cons " خَمْسَةٌ وَ تِسْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "6");;96xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سِتَّةٌ وَ تِسْعُونَ أَلفًا")
		        (cons " سِتَّةٌ وَ تِسْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "7");;97xxx 
			(if (just_zeros (cdr (cdr digits))) (list "سَبْعَةٌ وَ تِسْعُونَ أَلفًا")
		        (cons " سَبْعَةٌ وَ تِسْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "8");;98xxx 
			(if (just_zeros (cdr (cdr digits))) (list "ثَمَانِيَةٌ وَ تِسْعُونَ أَلفًا")
		        (cons " ثَمَانِيَةٌ وَ تِسْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))

		 ((string-equal (car (cdr digits)) "9");;99xxx 
			(if (just_zeros (cdr (cdr digits))) (list "تِسْعَةٌ وَ تِسْعُونَ أَلفًا")
		        (cons " تِسْعَةٌ وَ تِسْعُونَ أَلفًا وَ" (arabic_number_from_digits (cdr (cdr digits))))))
		 (t (list "رَقْمٌ"))));; else

       ))



     (t
      (list "رَقْمٌ كَبيرٌ"))))

)
;;;;;;;;;;;;;;;;;;;;;;;Number;;;;;;;;;;;;;;;;;;;;;;;;;


(provide 'ara_norm_ziad_tokenizer)
