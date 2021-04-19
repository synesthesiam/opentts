(define (ara_norm_addenda)
  "(ara_norm_addenda)
Basic lexicon should (must ?) have basic letters, symbols and punctuation."

;;; Pronunciation of letters in the alphabet
;(lex.add.entry '("a" nn (((a) 0))))
;(lex.add.entry '("b" nn (((b e) 0))))
;(lex.add.entry '("c" nn (((th e) 0))))
;(lex.add.entry '("d" nn (((d e) 0))))
;(lex.add.entry '("e" nn (((e) 0))))
; ...

;;; Symbols ...
;(lex.add.entry 
; '("*" n (((a s) 0) ((t e) 0) ((r i1 s) 1)  ((k o) 0))))
;(lex.add.entry 
; '("%" n (((p o r) 0) ((th i e1 n) 1) ((t o) 0))))

;; Basic punctuation must be in with nil pronunciation
(lex.add.entry '("." punc nil))
;(lex.add.entry '("." nn (((p u1 n) 1) ((t o) 0))))
(lex.add.entry '("'" punc nil))
(lex.add.entry '(":" punc nil))
(lex.add.entry '(";" punc nil))
(lex.add.entry '("," punc nil))
;(lex.add.entry '("," nn (((k o1) 1) ((m a) 0))))
(lex.add.entry '("-" punc nil))
(lex.add.entry '("\"" punc nil))
(lex.add.entry '("`" punc nil))
(lex.add.entry '("?" punc nil))
(lex.add.entry '("!" punc nil))

;;m=هذا
(lex.add.entry  
'("هذا" nil (((h aa) 0) ((th aa) 0))))  
(lex.add.entry  
'("هَذَا" nil (((h aa) 0) ((th aa) 0)))) 
;;m=بهذا
(lex.add.entry  
'("بهذا" nil (((b i) 0) ((h aa) 0) ((th aa) 0))))  
(lex.add.entry  
'("بِهَذَا" nil (((b i) 0) ((h aa) 0) ((th aa) 0))))  
;;m=كهذا
(lex.add.entry  
'("كهذا" nil (((k a) 0) ((h aa) 0) ((th aa) 0)))) 
(lex.add.entry   
'("كَهَذَا" nil (((k a) 0) ((h aa) 0) ((th aa) 0)))) 
;;m=فهذا
(lex.add.entry  
'("فهذا" nil (((f a) 0) ((h aa) 0) ((th aa) 0)))) 
(lex.add.entry  
'("فَهَذَا" nil (((f a) 0) ((h aa) 0) ((th aa) 0)))) 
;;m=هذه
(lex.add.entry  
'("هذه" nil (((h aa) 0) ((th i) 0) ((h i) 0)))) 
(lex.add.entry  
'("هَذِهِ" nil (((h aa) 0) ((th i) 0) ((h i) 0)))) 
;;m=بهذه
(lex.add.entry  
'("بهذه" nil (((b i) 0) ((h aa) 0) ((th i) 0) ((h i) 0)))) 
(lex.add.entry  
'("بِهَذِهِ" nil (((b i) 0) ((h aa) 0) ((th i) 0) ((h i) 0)))) 
;;m=كهذه
(lex.add.entry  
'("كهذه" nil (((k a) 0) ((h aa) 0) ((th i) 0) ((h i) 0)))) 
(lex.add.entry  
'("كَهَذِهِ" nil (((k a) 0) ((h aa) 0) ((th i) 0) ((h i) 0)))) 
;;m=فهذه
(lex.add.entry  
'("فهذه" nil (((f a) 0) ((h aa) 0) ((th i) 0) ((h i) 0)))) 
(lex.add.entry  
'("فَهَذِهِ" nil (((f a) 0) ((h aa) 0) ((th i) 0) ((h i) 0)))) 
;;m=هذان
(lex.add.entry  
'("هذان" nil (((h aa) 0) ((th aa) 0) ((n i) 0))))
(lex.add.entry  
'("هَذَانِ" nil (((h aa) 0) ((th aa) 0) ((n i) 0))))
;;m=هؤلاء
(lex.add.entry  
'("هؤلاء" nil (((h aa) 0) ((ah u) 0) ((l aa) 0) ((ah i) 0)))) 
(lex.add.entry  
'("هَؤُلَاءِ" nil (((h aa) 0) ((ah u) 0) ((l aa) 0) ((ah i) 0)))) 
;;m=ذلك
(lex.add.entry  
'("ذلك" nil (((th aa) 0) ((l i) 0) ((k a) 0))))
(lex.add.entry  
'("ذَلِكَ" nil (((th aa) 0) ((l i) 0) ((k a) 0))))
;;m=بذلك
(lex.add.entry  
'("بذلك" nil (((b i) 0) ((th aa) 0) ((l i) 0) ((k a) 0))))
(lex.add.entry  
'("بِذَلِكَ" nil (((b i) 0) ((th aa) 0) ((l i) 0) ((k a) 0))))
;;m=كذلك
(lex.add.entry  
'("كذلك" nil (((k a) 0) ((th aa) 0) ((l i) 0) ((k a) 0))))
(lex.add.entry  
'("كَذَلِكَ" nil (((k a) 0) ((th aa) 0) ((l i) 0) ((k a) 0))))
;;m=ذلكم
(lex.add.entry  
'("ذلكم" nil (((th aa) 0) ((l i) 0) ((k u m) 0))))
(lex.add.entry  
'("ذَلِكُمْ" nil (((th aa) 0) ((l i) 0) ((k u m) 0))))
;;m=أولئك
(lex.add.entry  
'("أولئك" nil (((ah u) 0) ((l aa) 0) ((ah i) 0) ((k a) 0))))
(lex.add.entry  
'("أُولَئِكَ" nil (((ah u) 0) ((l aa) 0) ((ah i) 0) ((k a) 0))))
;;m=طه
(lex.add.entry  
'("طه" nil (((T aa) 0) ((h a) 0))))
(lex.add.entry  
'("طَهَ" nil (((T aa) 0) ((h a) 0))))
;;m=لكن
(lex.add.entry  
'("لكن" nil (((l aa) 0) ((k i) 0) ((nn a) 0))))
(lex.add.entry  
'("لَكِنَّ" nil (((l aa) 0) ((k i) 0) ((nn a) 0))))
(lex.add.entry  
'("لَكِنْ" nil (((l aa) 0) ((k i n) 0))))
;;m=لكنه 
(lex.add.entry  
'("لكنه" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((h u) 0))))
(lex.add.entry  
'("لَكِنَّهُ" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((h u) 0))))
;;m=لكنها 
(lex.add.entry  
'("لكنها" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((h aa) 0))))
(lex.add.entry  
'("لَكِنَّهَا" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((h aa) 0))))
;;m=لكنهم 
(lex.add.entry  
'("لكنهم" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((h u m) 0))))
(lex.add.entry  
'("لَكِنَّهُمْ" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((h u m) 0))))
;;m=لكنك 
(lex.add.entry  
'("لَكِنَّكَ" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((k a) 0))))
(lex.add.entry  
'("لَكِنَّكِ" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((k i) 0))))
;;m=لكنكم 
(lex.add.entry  
'("لكنكم" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((k u m) 0))))
(lex.add.entry  
'("لَكِنَّكُمْ" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((k u m) 0))))
;;m=لكنكما 
(lex.add.entry  
'("لكنكما" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((k u) 0) ((m aa) 0))))
(lex.add.entry  
'("لَكِنَّكُمَا" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((k u) 0) ((m aa) 0))))
;;m=لكننا 
(lex.add.entry  
'("لكننا" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((n aa) 0))))
(lex.add.entry  
'("لَكِنَّنَا" nil (((l aa) 0) ((k i) 0) ((nn a) 0) ((n aa) 0))))
;;m=هذين
(lex.add.entry  
'("هذين" nil (((h aa) 0) ((th a y) 0) ((n i) 0))))  
(lex.add.entry  
'("هَذَيْنِ" nil (((h aa) 0) ((th a y) 0) ((n i) 0))))  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;; + waw +;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;m=وهذا
(lex.add.entry  
'("وهذا" nil (((w a) 0) ((h aa) 0) ((th aa) 0))))  
(lex.add.entry  
'("وَهَذَا" nil (((w a) 0) ((h aa) 0) ((th aa) 0)))) 
;;m=وبهذا
(lex.add.entry  
'("وبهذا" nil (((w a) 0) ((b i) 0) ((h aa) 0) ((th aa) 0))))  
(lex.add.entry  
'("وَبِهَذَا" nil (((w a) 0) ((b i) 0) ((h aa) 0) ((th aa) 0))))  
;;m=وكهذا
(lex.add.entry  
'("وكهذا" nil (((w a) 0) ((k a) 0) ((h aa) 0) ((th aa) 0)))) 
(lex.add.entry   
'("وَكَهَذَا" nil (((w a) 0) ((k a) 0) ((h aa) 0) ((th aa) 0)))) 
;;m=وهذه
(lex.add.entry  
'("وهذه" nil (((w a) 0) ((h aa) 0) ((th i) 0) ((h i) 0)))) 
(lex.add.entry  
'("وَهَذِهِ" nil (((w a) 0) ((h aa) 0) ((th i) 0) ((h i) 0)))) 
;;m=وبهذه
(lex.add.entry  
'("وبهذه" nil (((w a) 0) ((b i) 0) ((h aa) 0) ((th i) 0) ((h i) 0)))) 
(lex.add.entry  
'("وَبِهَذِهِ" nil (((w a) 0) ((b i) 0) ((h aa) 0) ((th i) 0) ((h i) 0)))) 
;;m=وكهذه
(lex.add.entry  
'("وكهذه" nil (((w a) 0) ((k a) 0) ((h aa) 0) ((th i) 0) ((h i) 0)))) 
(lex.add.entry  
'("وَكَهَذِهِ" nil (((w a) 0) ((k a) 0) ((h aa) 0) ((th i) 0) ((h i) 0)))) 
;;m=وهذان
(lex.add.entry  
'("وهذان" nil (((w a) 0) ((h aa) 0) ((th aa) 0) ((n i) 0))))
(lex.add.entry  
'("وَهَذَانِ" nil (((w a) 0) ((h aa) 0) ((th aa) 0) ((n i) 0))))
;;m=وهؤلاء
(lex.add.entry  
'("وهؤلاء" nil (((w a) 0) ((h aa) 0) ((ah u) 0) ((l aa) 0) ((ah i) 0)))) 
(lex.add.entry  
'("وَهَؤُلَاءِ" nil (((w a) 0) ((h aa) 0) ((ah u) 0) ((l aa) 0) ((ah i) 0)))) 
;;m=وذلك
(lex.add.entry  
'("وذلك" nil (((w a) 0) ((th aa) 0) ((l i) 0) ((k a) 0))))
(lex.add.entry  
'("وَذَلِكَ" nil (((w a) 0) ((th aa) 0) ((l i) 0) ((k a) 0))))
;;m=وبذلك
(lex.add.entry  
'("وبذلك" nil (((w a) 0) ((b i) 0) ((th aa) 0) ((l i) 0) ((k a) 0))))
(lex.add.entry  
'("وَبِذَلِكَ" nil (((w a) 0) ((b i) 0) ((th aa) 0) ((l i) 0) ((k a) 0))))
;;m=وكذلك
(lex.add.entry  
'("وكذلك" nil (((w a) 0) ((k a) 0) ((th aa) 0) ((l i) 0) ((k a) 0))))
(lex.add.entry  
'("وَكَذَلِكَ" nil (((w a) 0) ((k a) 0) ((th aa) 0) ((l i) 0) ((k a) 0))))
;;m=وذلكم
(lex.add.entry  
'("وذلكم" nil (((w a) 0) ((th aa) 0) ((l i) 0) ((k u m) 0))))
(lex.add.entry  
'("وَذَلِكُمْ" nil (((w a) 0) ((th aa) 0) ((l i) 0) ((k u m) 0))))
;;m=وأولئك
(lex.add.entry  
'("وأولئك" nil (((w a) 0) ((ah u) 0) ((l aa) 0) ((ah i) 0) ((k a) 0))))
(lex.add.entry  
'("وَأُولَئِكَ" nil (((w a) 0) ((ah u) 0) ((l aa) 0) ((ah i) 0) ((k a) 0))))
;;m=وطه
(lex.add.entry  
'("وطه" nil (((w a) 0) ((T aa) 0) ((h a) 0))))
(lex.add.entry  
'("وَطَهَ" nil (((w a) 0) ((T aa) 0) ((h a) 0))))
;;m=ولكن
(lex.add.entry  
'("ولكن" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0))))
(lex.add.entry  
'("وَلَكِنَّ" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0))))
(lex.add.entry  
'("وَلَكِنْ" nil (((w a) 0) ((l aa) 0) ((k i n) 0))))
;;m=ولكنه 
(lex.add.entry  
'("ولكنه" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((h u) 0))))
(lex.add.entry  
'("وَلَكِنَّهُ" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((h u) 0))))
;;m=ولكنها 
(lex.add.entry  
'("ولكنها" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((h aa) 0))))
(lex.add.entry  
'("وَلَكِنَّهَا" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((h aa) 0))))
;;m=ولكنهم 
(lex.add.entry  
'("ولكنهم" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((h u m) 0))))
(lex.add.entry  
'("وَلَكِنَّهُمْ" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((h u m) 0))))
;;m=ولكنك 
(lex.add.entry  
'("ولَكِنَّكَ" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((k a) 0))))
(lex.add.entry  
'("وَلَكِنَّكِ" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((k i) 0))))
;;m=ولكنكم 
(lex.add.entry  
'("ولكنكم" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((k u m) 0))))
(lex.add.entry  
'("وَلَكِنَّكُمْ" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((k u m) 0))))
;;m=ولكنكما 
(lex.add.entry  
'("ولكنكما" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((k u) 0) ((m aa) 0))))
(lex.add.entry  
'("وَلَكِنَّكُمَا" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((k u) 0) ((m aa) 0))))
;;m=ولكننا 
(lex.add.entry  
'("ولكننا" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((n aa) 0))))
(lex.add.entry  
'("وَلَكِنَّنَا" nil (((w a) 0) ((l aa) 0) ((k i) 0) ((nn a) 0) ((n aa) 0))))
;;m=وهذين
(lex.add.entry  
'("وهذين" nil (((w a) 0) ((h aa) 0) ((th a y) 0) ((n i) 0))))  
(lex.add.entry  
'("وَهَذَيْنِ" nil (((w a) 0) ((h aa) 0) ((th a y) 0) ((n i) 0))))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;m=و 
(lex.add.entry  
'("و" nil (((w a) 0))))
;;m=او 
(lex.add.entry  
'("او" nil (((ah a w) 0))))
(lex.add.entry  
'("اوْ" nil (((ah a w) 0))))
;;m=أو 
(lex.add.entry  
'("أو" nil (((ah a w) 0))))
(lex.add.entry  
'("أوْ" nil (((ah a w) 0))))
;;m=الف   
(lex.add.entry  
'("الف" nil (((ah a l f) 0))))
;;m=ألف   
(lex.add.entry  
'("ألف" nil (((ah a l f) 0))))
;;m=بألف   
(lex.add.entry  
'("بألف" nil (((b i) 0) ((ah a l f) 0))))
;;m=فألف   
(lex.add.entry  
'("فألف" nil (((f a) 0) ((ah a l f) 0))))
;;m=والف   
(lex.add.entry  
'("والف" nil (((w a) 0) ((ah a l f) 0))))
;;m=وألف   
(lex.add.entry  
'("وألف" nil (((w a) 0) ((ah a l f) 0))))
;;m=وبألف   
(lex.add.entry  
'("وبألف" nil (((w a) 0) ((b i) 0) ((ah a l f) 0))))
;;m=نت 
(lex.add.entry  
'("نت" nil (((n i t) 0))))
;;m=فيديو   
(lex.add.entry  
'("فيديو" nil (((v i) 0) ((d y uua) 0))))
(lex.add.entry  
'("فِيدْيُو" nil (((v i) 0) ((d y uua) 0))))
;;m=الفيديو   
(lex.add.entry  
'("الفيديو" nil (((ah a l) 0) ((v i) 0) ((d y uua) 0))))
(lex.add.entry  
'("الْفِيدْيُو" nil (((ah a l) 0) ((v i) 0) ((d y uua) 0))))	
(lex.add.entry  
'("الْفِيدْيُوُ" nil (((ah a l) 0) ((v i) 0) ((d y uua) 0))))
;;m=الله   
(lex.add.entry  
'("اللهَ" nil (((ah a ll) 0) ((aa) 0) ((h a) 0))))
(lex.add.entry  
'("اللهِ" nil (((ah a ll) 0) ((aa) 0) ((h i) 0))))
(lex.add.entry  
'("اللهُ" nil (((ah a ll) 0) ((aa) 0) ((h u) 0))))

)
