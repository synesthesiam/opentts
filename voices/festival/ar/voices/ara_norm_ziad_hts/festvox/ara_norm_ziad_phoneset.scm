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
;;; Phonset for ara_norm
;;;

;;;  Feeel free to add new feature values, or new features to this
;;;  list to make it more appropriate to your language

;; This is where it'll fall over if you haven't defined a 
;; a phoneset yet, if you have, delete this, if you haven't
;; define one then delete this error message
;;(error "You have not yet defined a phoneset for norm (and others things ?)\n            Define it in festvox/ara_norm_ziad_phoneset.scm\n")

(defPhoneSet
  ara_norm
  ;;;  Phone Features
  (;; vowel or consonant
   (vc + -)
   ;; vowel length: short long dipthong schwa
   (vlng s l d a 0)
   ;; vowel height: high mid low
   (vheight 1 2 3 0)
   ;; vowel frontness: front mid back
   (vfront 1 2 3 0)
   ;; lip rounding
   (vrnd + - 0)
   ;; consonant type: stop fricative affricative nasal liquid approximant
   (ctype s f a n l r 0)
   ;; place of articulation: labial alveolar palatal labio-dental dental velar glottal
   (cplace l a p b d v g 0)
   ;; consonant voicing
   (cvox + - 0)
   )
  (
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (ah   -   0   0   0   0   s   g   -) ;; hamza(ء) لا يهم اذا كانت فوق الف او واو او ياء او وحدها المهم صوتها))
   (ahh  -   0   0   0   0   s   g   -) ;; hamza+shada

   (b    -   0   0   0   0   s   l   +) ;; ba(ب)
   (bb   -   0   0   0   0   s   l   +) ;; ba+shada

   (t    -   0   0   0   0   s   a   -) ;;ta(ت)
   (tt   -   0   0   0   0   s   a   -) ;;ta+shada

   (^    -   0   0   0   0   f   d   -) ;; ^a(ث)
   (^^   -   0   0   0   0   f   d   -) ;; ^a+ishala

   (j    -   0   0   0   0   a   p   +) ;;jim(ج)
   (jj   -   0   0   0   0   a   p   +) ;;jim+shada

   (H    -   0   0   0   0   f   v   -) ;; 7a(ح)
   (HH   -   0   0   0   0   f   v   -) ;; 7a+shada

   (x    -   0   0   0   0   f   v   -) ;;xa(خ)
   (xx   -   0   0   0   0   f   v   -) ;;xa+shada

   (d    -   0   0   0   0   s   a   +) ;; dal(د) Voiced dental and alveolar stops
   (dd   -   0   0   0   0   s   a   +) ;; dal+shada

   (th   -   0   0   0   0   f   d   +) ;; thal(ذ) Voiced dental fricative
   (thh  -   0   0   0   0   f   d   +) ;; dal+shada

   (r    -   0   0   0   0   l   a   +) ;;ra(ر) Voiced dental, alveolar and postalveolar trills
   (rr   -   0   0   0   0   l   a   +) ;;ra+shada

   (z    -   0   0   0   0   f   a   +) ;;za(ز) Voiced alveolar fricative
   (zz   -   0   0   0   0   f   a   +) ;;za+shada

   (s    -   0   0   0   0   f   a   -) ;;sin(س) Voiceless alveolar fricative /Voiceless alveolar sibilants 
   (ss   -   0   0   0   0   f   a   -) ;;sin+shada

   (ch   -   0   0   0   0   f   p   -) ;; shin(ش) Voiceless palato-alveolar fricative
   (chh  -   0   0   0   0   f   p   -) ;; shin+shada 

   (S    -   0   0   0   0   f   a   -) ;; sad(ص) unvoiced pharyngealized apical alveolar sibilant fricative
   (SS   -   0   0   0   0   f   a   -) ;; sad+shada

   (D    -   0   0   0   0   s   a   +) ;; dad(ض) voiced unaspirated pharyngealized apical alveolar stop
   (DD   -   0   0   0   0   s   a   +) ;; dad+shada

   (T    -   0   0   0   0   s   a   -) ;; Ta(ط) unvoiced unaspirated pharyngealized apical alveolar stop
   (TT   -   0   0   0   0   s   a   -) ;; Ta+shada

   (Z    -   0   0   0   0   f   a   +) ;; dad_ishala(ظ) voiced pharyngealized apical alveolar sibilant fricative
   (ZZ   -   0   0   0   0   f   a   +) ;; dad_ishala+shada

   (E    -   0   0   0   0   f   v   +) ;; ain(ع) voiced radical pharyngeal non sibilant fricative
   (EE   -   0   0   0   0   f   v   +) ;; ain+shada

   (g    -   0   0   0   0   f   v   +) ;; ghin(غ) voiced dorsal velar non sibilant fricative

   (gg   -   0   0   0   0   f   v   +) ;; ghin+shada

   (f    -   0   0   0   0   f   b   -) ;; fa(ف) Voiceless labiodental fricative
   (ff   -   0   0   0   0   f   b   -) ;; fa+shada

   (q    -   0   0   0   0   s   v   -) ;;qaf(ق) Voiceless uvular stop
   (qq   -   0   0   0   0   s   v   -) ;;qaf+shada

   (k    -   0   0   0   0   s   v   -) ;;kaf(ك) Voiceless velar stop
   (kk   -   0   0   0   0   s   v   -) ;;kaf+shada

   (l    -   0   0   0   0   r   a   +) ;;lam(ل) Voiced dental, alveolar and postalveolar lateral approximants
   (ll   -   0   0   0   0   r   a   +) ;;lam+shada

   (m    -   0   0   0   0   n   l   +) ;;mim(م) Voiced bilabial nasal
   (mm   -   0   0   0   0   n   l   +) ;;mim+shada

   (n    -   0   0   0   0   n   a   +) ;;noun(ن) Voiced dental, alveolar and postalveolar nasals
   (nn   -   0   0   0   0   n   a   +) ;;noun+shada 

   (h    -   0   0   0   0   f   g   -) ;; ha(هـ) Voiceless glottal fricative
   (hh   -   0   0   0   0   f   g   -) ;; ha+shada 

   (w    -   0   0   0   0   r   l   +) ;;wa(و) Voiced labio-velar approximant
   (ww   -   0   0   0   0   r   l   +) ;;wa+shada

   (y    -   0   0   0   0   r   p   +) ;;ya(ي) Voiced palatal approximant
   (yy   -   0   0   0   0   r   p   +) ;;ya+shada

   (v    -   0   0   0   0   f   b   +) ;;vidéo 
	; TODO: add letter p and g as extension of arabic to read forign nouns
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   (a    +   s   3   2   -   0   0   0) ;;fatha
   (aa   +   l   3   2   -   0   0   0) ;;fatha+mad

   (A    +   s   3   2   -   0   0   0) ;;fatha+(ص,ض,ط,ظ,ق) 
   (AA   +   l   3   2   -   0   0   0) ;;fatha+mad+(ص,ض,ط,ظ,ق) (fiha chak)

   (i    +   s   1   1   -   0   0   0) ;;ziad:i0 kasra
   (ia   +   s   1   1   -   0   0   0) ;;ziad:i1 kasra toukarib al fatha
   (ii   +   l   1   1   -   0   0   0) ;;ziad:ii0 kasra+mad

   (I    +   s   1   1   -   0   0   0) ;;ziad:I0 kasra+(ص,ض,ط,ظ,ق)
   (II   +   l   1   1   -   0   0   0) ;;ziad:II0 kasra+mad+(ص,ض,ط,ظ,ق) (fiha chak)

   (u    +   s   1   3   +   0   0   0) ;;ziad:u0 dama
   (uu   +   l   1   3   +   0   0   0) ;;ziad:uu0 dama+mad
   
   (U    +   s   1   3   +   0   0   0) ;;ziad:U0 dama+(ص,ض,ط,ظ,ق)
   (UU   +   l   1   3   +   0   0   0) ;;ziad:UU0 dama+mad+(ص,ض,ط,ظ,ق) (fiha chak)

   (ua   +   s   1   3   +   0   0   0) ;;ziad:u1 dama toukarib al fatha
   (uua  +   l   1   3   +   0   0   0) ;;ziad:uu1 (الفيديو) vidyuua

   (sil  -   0   0   0   0   0   0   -) ;;

   (pau  -   0   0   0   0   0   0   -) ;;

   ;; insert the phones here, see examples in 
   ;; festival/lib/*_phones.scm

  )
)

(PhoneSet.silences '(pau))

(define (ara_norm_ziad::select_phoneset)
  "(ara_norm_ziad::select_phoneset)
Set up phone set for ara_norm."
  (Parameter.set 'PhoneSet 'ara_norm)
  (PhoneSet.select 'ara_norm)
)

(define (ara_norm_ziad::reset_phoneset)
  "(ara_norm_ziad::reset_phoneset)
Reset phone set for ara_norm."
  t
)

(provide 'ara_norm_ziad_phoneset)
