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
;;; Lexicon, LTS and Postlexical rules for ara_norm
;;;

;;; Load any necessary files here


(require 'lts)

;;;  Function called when word not found in lexicon
;;;  and you've trained letter to sound rules
;(define (ara_norm_lts_function word features)
;  "(ara_norm_lts_function WORD FEATURES)
;Return pronunciation of word not in lexicon."

  ;; If you have nothing ...
;  (format t "Unknown word %s\n" word)
;  (list word features nil)

  ;; If you have lts rules (trained or otherwise)
;  (if (not boundp 'ara_norm_lts_rules)
;      (require 'ara_norm_lts_rules))
;  (let ((dword (downcase word)) (phones) (syls))
;    (set! phones (lts_predict dword ara_norm_lts_rules))
;    (set! syls (ara_norm_lex_syllabify_phstress phones))
;    (list word features syls))
;  )

(define (ara_norm_map_modify ps)
  (cond
   ((null ps) nil)
   ((null (cdr ps)) ps)
   ((assoc_string (string-append (car ps) (cadr ps))
                   ara_norm_ziad_char_phone_map)
    (cons
     (string-append (car ps) (cadr ps))
     (ara_norm_map_modify (cddr ps))))
   (t
    (cons
     (car ps)
     (ara_norm_map_modify (cdr ps))))))

(define (ara_norm_map_phones p)
  (cond
   ((null p) nil)
   (t
    (let ((a (assoc_string (car p) ara_norm_ziad_char_phone_map)))
      (cond
       (a (cons (cadr a) (ara_norm_map_phones (cdr p))))
       (t (ara_norm_map_phones (cdr p))))))))

(define (ara_norm_is_vowel x)
  (string-equal "+" (phone_feature x "vc")))

(define (ara_norm_contains_vowel l)
  (member_string
   t
   (mapcar (lambda (x) (ara_norm_is_vowel x)) l)))

(define (ara_norm_lex_sylbreak currentsyl remainder)
  "(ara_norm_lex_sylbreak currentsyl remainder)
t if this is a syl break, nil otherwise."
  (cond
   ((not (ara_norm_contains_vowel remainder))
    nil)
   ((not (ara_norm_contains_vowel currentsyl))
    nil)
   (t
    ;; overly naive, I mean wrong
    t))
)

;(define (ara_norm_lex_syllabify_phstress phones)
; (let ((syl nil) (syls nil) (p phones) (stress 0))
;    (while p
;     (set! syl nil)
;     (set! stress 0)
;     (while (and p (not (ara_norm_lex_sylbreak syl p)))
;       (if (string-matches (car p) "xxxx")
;           (begin
;             ;; whatever you do to identify stress
;             (set! stress 1)
;             (set syl (cons (car p-stress) syl)))
;           (set! syl (cons (car p) syl)))
;       (set! p (cdr p)))
;     (set! syls (cons (list (reverse syl) stress) syls)))
;    (reverse syls)))
  

(define (sampa_lookup gphones)
  (let ((phlist nil) (sp nil))
    (mapcar 
     (lambda (gg)
       (set! sp (assoc_string gg unicode_sampa_mapping))
       (if sp
           (set! phlist (append (car (cadr sp)) phlist))
           (set! phlist (cons gg phlist))))
     gphones)
    (reverse phlist)))

;(define (indic_unicode_lts phlist)
;	(set! finallist (list))
;	(set! graphemecount 0)
;	(set! prevgrapheme (list))
;	(set! totgcnt (- (length phlist) 1))
;	(mapcar (lambda (ggg)
;		(if (symbol? (car ggg))
;		(begin
;		(cond
;			;; schwa deletion for the last consonant
;			((equal? graphemecount totgcnt)
;			(begin
;				(if (string-equal (phone_feature (car ggg) 'vc) "-")
;				(begin 
;					(if (string-equal (phone_feature (car prevgrapheme) 'vc) "-") 
;					(set! finallist (append  finallist prevgrapheme)))
;					;(set! finallist (append finallist (list (car ggg)))) ;appropriate for hindi
;					(set! finallist (append finallist  ggg)) ; for generic (non-schwa final) indic
;				)
;				(begin 
;					(if (string-equal (phone_feature (car prevgrapheme) 'vc) "-") 
;					(set! finallist (append finallist (list (car prevgrapheme)))))
;					(set! finallist (append finallist (list (car ggg))))
;				))
;			))
;			;; generic treatment for an intermediate grapheme
;			((and (> graphemecount 0) (< graphemecount totgcnt))
;			(begin
;				(cond 
;					;; If current is vowel, remove the previous schwa
;					((and (string-equal (phone_feature (car ggg) 'vc) "+") (string-equal (phone_feature (car prevgrapheme) 'vc) "-"))
;					(begin 
;						(set! finallist (append finallist (list (car prevgrapheme))))
;						(set! finallist (append finallist (list (car ggg))))
;					))
;					;; If current is consonant and previous is consonant, dump all of previous 
;					((and  (string-equal (phone_feature (car ggg) 'vc) "-") (string-equal (phone_feature (car prevgrapheme) 'vc) "-"))
;					(set! finallist (append finallist prevgrapheme)))
;					(t 
;					 t)
;				)
;			))
;			((and (eq? graphemecount 0) (string-equal (phone_feature (car ggg) 'vc) "+"))
;				(set! finallist (list (car ggg)))
;			)
;			(t 
;			t)
;		)
;		(set! graphemecount (+ 1 graphemecount))
;		(set! prevgrapheme ggg)
;		)
;		(begin 
;			(cond
;				((equal? (car ggg) '(P))
;					(set! finallist (append finallist (list (car prevgrapheme))))
;					(set! prevgrapheme (list))
;				)
;				((equal? (car ggg) '(M))
;					(if (string-equal (phone_feature (car prevgrapheme) 'vc) "-") (set! finallist (append finallist prevgrapheme)))
;					(set! finallist (append finallist (list "nB")))
;					(set! prevgrapheme (list))
;				)
;				((equal? (car ggg) '(CD))
;					(if (string-equal (phone_feature (car prevgrapheme) 'vc) "-") (set! finallist (append finallist prevgrapheme)))
;					(set! finallist (append finallist (list "nB")))
;					(set! prevgrapheme (list))
;				)
;				(t
;				t)
;				;(format t "debug: todo \n")
;			)
;			(set! graphemecount (+ 1 graphemecount))
;		)
;	)
;	) phlist)
;finallist)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; OR: Hand written letter to sound rules
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(if (probe_file (path-append ara_norm_ziad_hts::hts_dir "/usr/share/festival/voices/arabic/ara_norm_ziad_hts/festvox/ara_norm_ziad_char_phone_map.scm"))
    (begin
      (set! ara_norm_ziad_char_phone_map
            (load (path-append ara_norm_ziad_hts::hts_dir 
                               "/usr/share/festival/voices/arabic/ara_norm_ziad_hts/festvox/ara_norm_ziad_char_phone_map.scm") t))
	(load (path-append ara_norm_ziad_hts::hts_dir 
                           "/usr/share/festival/voices/arabic/ara_norm_ziad_hts/festvox/unicode_sampa_mapping.scm"))))
; ;;;  Function called when word not found in lexicon
 (define (ara_norm_lts_function word features)
   "(ara_norm_lts_function WORD FEATURES)
 Return pronunciation of word not in lexicon."

;   (format stderr "failed to find pronunciation for %s\n" word)
   (let ((dword (downcase word)))
        (set! aphones (ara_norm_map_modify (utf8explode dword)))
        (set! phones (ara_norm_map_phones aphones))
	(set! phones (sampa_lookup phones))
;     ;; Note you may need to use a letter to sound rule set to do
;     ;; casing if the language has non-ascii characters in it.

     (if (lts.in.alphabet phones 'ara_norm)
 	(list
 	 phones
 	 features

 	 ; (format stderr "%s\n" word)
; 	 ;; This syllabification is almost certainly wrong for
; 	 ;; this language (its not even very good for English)
; 	 ;; but it will give you something to start off with
 	 (lex.syllabify.phstress
 	   (lts.apply phones 'ara_norm)))
)
)
 )

; ;; You may or may not be able to write a letter to sound rule set for
; ;; your language.  If its largely lexicon based learning a rule
; ;; set will be better and easier that writing one (probably).

 (lts.ruleset ;;start lts.rules
  ara_norm

  (;;start list
	
	;;first list unicode
	  ( cs > < } & "\'" b t ^ j H x d * r z s $ S D T Z E g f q k l m n h w y | ) ;;consonants
	  ( ept D S T Z g x q ) ;;emphatics
	  ( fwe g x ) ;;forwardEmphatics
	  ( amcsn l w y p ) ;;ambiguousConsonant ;;These consonants are only unambiguous in certain contexts

	  ( dct o a u i F N K ~ ) ;;diacritics
	  ( dtws o a u i F N K ) ;;diacriticsWithoutShadda
	;;end

	;;the list used after rules
	  ( vy a i u ) ;;vowel
	  ( cnt ah b t ^ j H x d th r z s ch S D T Z E g f q k l m n h w y ) ;;consonant


  );;end list
   

  (;;start rules

	  ( # [ s i l ] # = sil );;
	;;;; Al chamsiya fi awal al kalima
	  ( # [ A l ] t = ah a )
	  ( # [ A l ] ^ = ah a )
	  ( # [ A l ] d = ah a )
	  ( # [ A l ] * = ah a )
	  ( # [ A l ] r = ah a )
	  ( # [ A l ] z = ah a )
	  ( # [ A l ] s = ah a )
	  ( # [ A l ] $ = ah a )
	  ( # [ A l ] S = ah a )
	  ( # [ A l ] D = ah a )
	  ( # [ A l ] T = ah a )
	  ( # [ A l ] Z = ah a )
	  ( # [ A l ] l = ah a )
	  ( # [ A l ] n = ah a )
	;;;;

	;;;; Al chamsiya fi wasat al kalima
	  ( [ a A l ] t = a )
	  ( [ a A l ] ^ = a )
	  ( [ a A l ] d = a )
	  ( [ a A l ] * = a )
	  ( [ a A l ] r = a )
	  ( [ a A l ] z = a )
	  ( [ a A l ] s = a )
	  ( [ a A l ] $ = a )
	  ( [ a A l ] S = a )
	  ( [ a A l ] D = a )
	  ( [ a A l ] T = a )
	  ( [ a A l ] Z = a )
	  ( [ a A l ] l = a )
	  ( [ a A l ] n = a )

	  ( [ i A l ] t = i )
	  ( [ i A l ] ^ = i )
	  ( [ i A l ] d = i )
	  ( [ i A l ] * = i )
	  ( [ i A l ] r = i )
	  ( [ i A l ] z = i )
	  ( [ i A l ] s = i )
	  ( [ i A l ] $ = i )
	  ( [ i A l ] S = i )
	  ( [ i A l ] D = i )
	  ( [ i A l ] T = i )
	  ( [ i A l ] Z = i )
	  ( [ i A l ] l = i )
	  ( [ i A l ] n = i )
	;;;;

	;;;; Al kamariya fi awal al kalima
	  ( # [ A l o ] < = ah a l )
	  ( # [ A l o ] > = ah a l )
	  ( # [ A l o ] | = ah a l )
	  ( # [ A l o ] b = ah a l )
	  ( # [ A l o ] j = ah a l )
	  ( # [ A l o ] H = ah a l )
	  ( # [ A l o ] x = ah a l )
	  ( # [ A l o ] E = ah a l )
	  ( # [ A l o ] g = ah a l )
	  ( # [ A l o ] f = ah a l )
	  ( # [ A l o ] q = ah a l )
	  ( # [ A l o ] k = ah a l )
	  ( # [ A l o ] m = ah a l )
	  ( # [ A l o ] h = ah a l )
	  ( # [ A l o ] w = ah a l )
	  ( # [ A l o ] y = ah a l )
	;;;;

	;;;; Al kamariya fi wasat al kalima
	  ( [ a A l o ] < = a l )
	  ( [ a A l o ] > = a l )
	  ( [ a A l o ] | = a l )
	  ( [ a A l o ] b = a l )
	  ( [ a A l o ] j = a l )
	  ( [ a A l o ] H = a l )
	  ( [ a A l o ] x = a l )
	  ( [ a A l o ] E = a l )
	  ( [ a A l o ] g = a l )
	  ( [ a A l o ] f = a l )
	  ( [ a A l o ] q = a l )
	  ( [ a A l o ] k = a l )
	  ( [ a A l o ] m = a l )
	  ( [ a A l o ] h = a l )
	  ( [ a A l o ] w = a l )
	  ( [ a A l o ] y = a l )

	  ( [ i A l o ] < = i l )
	  ( [ i A l o ] > = i l )
	  ( [ i A l o ] | = i l )
	  ( [ i A l o ] b = i l )
	  ( [ i A l o ] j = i l )
	  ( [ i A l o ] H = i l )
	  ( [ i A l o ] x = i l )
	  ( [ i A l o ] E = i l )
	  ( [ i A l o ] g = i l )
	  ( [ i A l o ] f = i l )
	  ( [ i A l o ] q = i l )
	  ( [ i A l o ] k = i l )
	  ( [ i A l o ] m = i l )
	  ( [ i A l o ] h = i l )
	  ( [ i A l o ] w = i l )
	  ( [ i A l o ] y = i l )
	;;;;

	;;;;
	  ( # [ A l ~ ] = ah a ll )
	  ( [ a A l ~ ] = a ll )
	  ( [ i A l ~ ] = i ll )
	;;;;

	;;;;shada+kasratayn (mouchkil : al kasratayn touktaban kabla shada wa la nastati3 tahwil shada wahdaha)
	  ( [ < K ~ ] = ahh ia n )
	  ( [ b K ~ ] = bb ia n )
	  ( [ t K ~ ] = tt ia n )
	  ( [ ^ K ~ ] = ^^ ia n )
	  ( [ j K ~ ] = jj ia n )	
	  ( [ H K ~ ] = HH ia n )  
	  ( [ x K ~ ] = xx ia n )
	  ( [ d K ~ ] = dd ia n )
	  ( [ * K ~ ] = thh ia n )
	  ( [ r K ~ ] = rr ia n )
	  ( [ z K ~ ] = zz ia n )
	  ( [ s K ~ ] = ss ia n )
	  ( [ $ K ~ ] = chh ia n )
	  ( [ S K ~ ] = SS ia n )
	  ( [ D K ~ ] = DD ia n )
	  ( [ T K ~ ] = TT ia n )
	  ( [ Z K ~ ] = ZZ ia n )
	  ( [ E K ~ ] = EE ia n )
	  ( [ g K ~ ] = gg ia n )
	  ( [ f K ~ ] = ff ia n )
	  ( [ q K ~ ] = qq ia n )
	  ( [ k K ~ ] = kk ia n )
	  ( [ l K ~ ] = ll ia n )
	  ( [ m K ~ ] = mm ia n )
	  ( [ n K ~ ] = nn ia n )
	  ( [ h K ~ ] = hh ia n )
	  ( [ w K ~ ] = ww ia n )
	  ( [ y K ~ ] = yy ia n )
	;;
	  ( [ > K ~ ] = ahh ia n )		;;alif fawkaha hamza+shada
	  ( [ "\'" K ~ ] = ahh ia n )	;;hamza+shada
	  ( [ } K ~ ] = ahh ia n )		;;alif maksora fawkaha hamza+shada
	  ( [ & K ~ ] = ahh ia n )		;;waw fawkaha hamza+shada 
	  ( [ | K ~ ] = ahh aa ia n)	;;alif almad+shada 
	;;;;
	
	;;;;shada
	  ( [ < ~ ] = ahh )
	  ( [ b ~ ] = bb )
	  ( [ t ~ ] = tt )
	  ( [ ^ ~ ] = ^^ )
	  ( [ j ~ ] = jj )	
	  ( [ H ~ ] = HH )  
	  ( [ x ~ ] = xx )
	  ( [ d ~ ] = dd )
	  ( [ * ~ ] = thh )
	  ( [ r ~ ] = rr )
	  ( [ z ~ ] = zz )
	  ( [ s ~ ] = ss )
	  ( [ $ ~ ] = chh )
	  ( [ S ~ ] = SS )
	  ( [ D ~ ] = DD )
	  ( [ T ~ ] = TT )
	  ( [ Z ~ ] = ZZ )
	  ( [ E ~ ] = EE )
	  ( [ g ~ ] = gg )
	  ( [ f ~ ] = ff )
	  ( [ q ~ ] = qq )
	  ( [ k ~ ] = kk )
	  ( [ l ~ ] = ll )
	  ( [ m ~ ] = mm )
	  ( [ n ~ ] = nn )
	  ( [ h ~ ] = hh )
	  ( [ w ~ ] = ww )
	  ( [ y ~ ] = yy )
	;;
	  ( [ > ~ ] = ahh )	;;alif fawkaha hamza+shada
	  ( [ "\'" ~ ] = ahh )	;;hamza+shada
	  ( [ } ~ ] = ahh )	;;alif maksora fawkaha hamza+shada
	  ( [ & ~ ] = ahh )	;;waw fawkaha hamza+shada 
	  ( [ | ~ ] = ahh aa )	;;alif almad+shada 
	;;
	;;;;

	;;;;soukoun
	  ( [ < o ] = ah )
	  ( [ b o ] = b )
	  ( [ t o ] = t )
	  ( [ ^ o ] = ^ )
	  ( [ j o ] = j )	
	  ( [ H o ] = H )  
	  ( [ x o ] = x )
	  ( [ d o ] = d )
	  ( [ * o ] = th )
	  ( [ r o ] = r )
	  ( [ z o ] = z )
	  ( [ s o ] = s )
	  ( [ $ o ] = ch )
	  ( [ S o ] = S )
	  ( [ D o ] = D )
	  ( [ T o ] = T )
	  ( [ Z o ] = Z )
	  ( [ E o ] = E )
	  ( [ g o ] = g )
	  ( [ f o ] = f )
	  ( [ q o ] = q )
	  ( [ k o ] = k )
	  ( [ l o ] = l )
	  ( [ m o ] = m )
	  ( [ n o ] = n )
	  ( [ h o ] = h )
	  ( [ w o ] = w )
	  ( [ y o ] = y )
	;;
	  ( [ > o ] = ah )	;;alif fawkaha hamza+soukoun
	  ( [ "\'" o ] = ah )	;;hamza+soukoun
	  ( [ } o ] = ah )	;;alif maksora fawkaha hamza+soukoun
	  ( [ & o ] = ah )	;;waw fawkaha hamza+soukoun
	  ( [ | o ] = ah aa )	;;alif almad+soukoun
	;;

	;;;;do some normalisation
	  ( # [ A i ] =  )	
	  ( [ A F ] = a n )	;;alif+fathatan
	  ( [ F A ] = a n )	;;fathatan+alif
	  ( [ F ] = a n )	;;fathatan
	  ( [ N ] = ua n )	;;damatan
	  ( [ K ] = ia n )	;;kasratan
	;;;;

	;;;;alif maksora
	  ( [ a Y ] = aa )	
	  ( [ Y a ] = aa )
	  ( [ i Y ] = ii )
	  ( [ Y ] = aa )			
	;;;;

	;;;;alif+(ص,ض,ط,ظ,ق)
	  ( [ a A ] S = AA )	;;fatha+alif
	  ( [ a A ] D = AA )	
	  ( [ a A ] T = AA )	
	  ( [ a A ] Z = AA )	
	  ( [ a A ] q = AA )	

	  ( [ A ] S = AA )	;;alif
	  ( [ A ] D = AA )
	  ( [ A ] T = AA )	
	  ( [ A ] Z = AA )	
	  ( [ A ] q = AA )		
	;;;;

	;;;;alif
	  ( [ a A ] = aa )	;;fatha+alif
	  ( [ A ] = aa )	;;alif
	;;;;

	;;;;waw+(ص,ض,ط,ظ,ق) fiha chak
	  ( [ u w ] S = UU )	;;dama+waw+harf
	  ( [ u w ] D = UU )	
	  ( [ u w ] T = UU )	
	  ( [ u w ] Z = UU )	
	  ( [ u w ] q = UU )	

	  ( cs [ w ] S = UU )	;;dama+waw+harf
	  ( cs [ w ] D = UU )
	  ( cs [ w ] T = UU )	
	  ( cs [ w ] Z = UU )	
	  ( cs [ w ] q = UU )		
	;;;;

	;;;;waw
	  ( [ u w A ] # = uu )	;;dama+waw+alif FIN
	  ( [ u w ] # = uu )	;;dama+waw FIN
	  ( [ ~ w ] # = uu )	;;shada+waw FIN
	  ( [ u w ] cs = uu )	;;dama+waw+harf
	  ( cs [ w ] cs = uu )	;;dama+waw+harf
	;;;;

	;;;;ya+(ص,ض,ط,ظ,ق) fiha chak
	  ( [ i y ] S = II )	;;kasra+ya+consonant
	  ( [ i y ] D = II )	
	  ( [ i y ] T = II )	
	  ( [ i y ] Z = II )	
	  ( [ i y ] q = II )	

	  ( cs [ y ] S = II )  ;;consonant+ya+consonant
	  ( cs [ y ] D = II )  
	  ( cs [ y ] T = II )  
	  ( cs [ y ] Z = II )  
	  ( cs [ y ] q = II )  
	;;;;

	;;;;ya
	  ( [ i y ] # = ii )	;;kasra+ya FIN
	  ( [ ~ y ] # = ii )	;;shada+ya FIN
	  ( [ i y ] cs = ii )	;;kasra+ya+consonant
	  ( cs [ y ] cs = ii )  ;;consonant+ya+consonant
	;;;;

	;;;;phone(ia)
	  ( [ i ] cs o # = ia )	;;kasra+consonant+soukoun FIN
	  ( [ i ] cs # = ia )	;;kasra+consonant FIN
	;;;;

	;;;;phone(ua)
	  ( [ u ] cs o # = ua )	;;dama+consonant+soukoun FIN
	  ( [ u ] cs # = ua )	;;dama+consonant FIN
	;;;;

        ;;;;ta marbota
	  ( [ p ] # =  )	;;ta marbota FIN
	  ( [ p ] = t )		;;ta marbota
        ;;;;
 
        ;;;;vowel+(ص,ض,ط,ظ,ق)
	  ( [ a ] S = A )
	  ( [ a ] D = A )
	  ( [ a ] T = A )
	  ( [ a ] Z = A )
	  ( [ a ] q = A )
	  ( [ i ] S = I )
	  ( [ i ] D = I )
	  ( [ i ] T = I )
	  ( [ i ] Z = I )
	  ( [ i ] q = I )
	  ( [ u ] S = U )
	  ( [ u ] D = U )
	  ( [ u ] T = U )
	  ( [ u ] Z = U )
	  ( [ u ] q = U )
        ;;;;

        ;;;;vowel
	  ( [ a ] = a )
	  ( [ i ] = i )
	  ( [ u ] = u )
	  ( [ o ] =  )
        ;;;;

	;;;;Consonant
	  ( [ < ] = ah )
	  ( [ b ] = b )
	  ( [ t ] = t )
	  ( [ ^ ] = ^ )
	  ( [ j ] = j )	
	  ( [ H ] = H )  
	  ( [ x ] = x )
	  ( [ d ] = d )
	  ( [ * ] = th )
	  ( [ r ] = r )
	  ( [ z ] = z )
	  ( [ s ] = s )
	  ( [ $ ] = ch )
	  ( [ S ] = S )
	  ( [ D ] = D )
	  ( [ T ] = T )
	  ( [ Z ] = Z )
	  ( [ E ] = E )
	  ( [ g ] = g )
	  ( [ f ] = f )
	  ( [ q ] = q )
	  ( [ k ] = k )
	  ( [ l ] = l )
	  ( [ m ] = m )
	  ( [ n ] = n )
	  ( [ h ] = h )
	  ( [ w ] = w )
	  ( [ y ] = y )
	;;
	  ( [ > ] = ah )		;;alif fawkaha hamza
	  ( [ "\'" ] = ah )	;;hamza
	  ( [ } ] = ah )		;;alif maksora fawkaha hamza
	  ( [ & ] = ah )		;;waw fawkaha hamza 
	  ( [ | ] = ah aa )	;;alif almad 
        ;;

        ;;;;madda
        ;;;;

        ;;;;nunation
        ;;;;

   );;end rules

 );;end lts.rules

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Postlexical Rules 
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (ara_norm::postlex_rule1 utt)
  "(ara_norm::postlex_rule1 utt)
A postlexical rule form correcting phenomena over word boundaries."
  (mapcar
   (lambda (s)
     ;; do something
     )
   (utt.relation.items utt 'Segment))
   utt)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Lexicon definition
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(lex.create "ara_norm")
(lex.set.phoneset "ara_norm")
(lex.set.lts.method 'ara_norm_lts_function)
;(if (probe_file (path-append ara_norm_ziad::dir "festvox/ara_norm_lex.out"))
;    (lex.set.compile.file (path-append ara_norm_ziad::dir 
;                                       "festvox/ara_norm_lex.out")))

(if (probe_file (path-append ara_norm_ziad_hts::hts_dir "/usr/share/festival/voices/arabic/ara_norm_ziad_hts/festvox/ara_norm_addenda.scm"))
    (load (path-append ara_norm_ziad_hts::hts_dir "/usr/share/festival/voices/arabic/ara_norm_ziad_hts/festvox/ara_norm_addenda.scm")))

(ara_norm_addenda)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Lexicon setup
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (ara_norm_ziad::select_lexicon)
  "(ara_norm_ziad::select_lexicon)
Set up the lexicon for ara_norm."
  (lex.select "ara_norm")

  ;; Post lexical rules
  (set! postlex_rules_hooks (list ara_norm::postlex_rule1))
)

(define (ara_norm_ziad::reset_lexicon)
  "(ara_norm_ziad::reset_lexicon)
Reset lexicon information."
  t
)

(provide 'ara_norm_ziad_lexicon)
