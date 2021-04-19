;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;                                                                       ;;
;;;                     Carnegie Mellon University                        ;;
;;;                      Copyright (c) 2005-2009                          ;;
;;;                        All Rights Reserved.                           ;;
;;;                                                                       ;;
;;;  Permission is hereby granted, free of charge, to use and distribute  ;;
;;;  this software and its documentation without restriction, including   ;;
;;;  without limitation the rights to use, copy, modify, merge, publish,  ;;
;;;  distribute, sublicense, and/or sell copies of this work, and to      ;;
;;;  permit persons to whom this work is furnished to do so, subject to   ;;
;;;  the following conditions:                                            ;;
;;;   1. The code must retain the above copyright notice, this list of    ;;
;;;      conditions and the following disclaimer.                         ;;
;;;   2. Any modifications must be clearly marked as such.                ;;
;;;   3. Original authors' names are not deleted.                         ;;
;;;   4. The authors' names are not used to endorse or promote products   ;;
;;;      derived from this software without specific prior written        ;;
;;;      permission.                                                      ;;
;;;                                                                       ;;
;;;  CARNEGIE MELLON UNIVERSITY AND THE CONTRIBUTORS TO THIS WORK         ;;
;;;  DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING      ;;
;;;  ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO         ;;
;;;  EVENT SHALL CARNEGIE MELLON UNIVERSITY NOR THE CONTRIBUTORS BE       ;;
;;;  LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY     ;;
;;;  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,      ;;
;;;  WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS       ;;
;;;  ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR              ;;
;;;  PERFORMANCE OF THIS SOFTWARE.                                        ;;
;;;                                                                       ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;                                                                       ;;
;;;  Author: Alan W Black (awb@cs.cmu.edu) Nov 2005                       ;;
;;;                                                                       ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;                                                                       ;;
;;;  Use wagon to do the HMM-state clustering and indexing for HTS        ;;
;;;  We are skipping the HTK part to give us more control over the        ;;
;;;  features (the multiple mapping isn't very portable across languages) ;;
;;;                                                                       ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  As the size of utterances can get *very* big, we don't follow clunits
;;;  doing processing on all utterances, but do things utt by utt.
;;;  This means unit type specific splitting happens later in the process
;;;
;;;  Thus:
;;;
;;;  for each utt
;;;     load hmmstates
;;;     load related combined cooefficients (F0, static mcep, delta mcep, v)
;;;     name the units
;;;     dump the vectors for each unittype
;;;     dump the features for each unittype
;;;
;;;  extract unit specific vector and feat files
;;;
;;;  do clustering (cross-validation or stepwise) of each unittype
;;;  collect trees into single file
;;;
;;;  12/01/06 non-cv non-stepwise is now the default, its fastest and
;;;           gives better results (for slt) than the cuter techniques
;;;  17/01/06 make F0, Duration, and Spectral models different and
;;;           dump all the data at the same time
;;;  25/02/06 trajectory modeling
;;;  03/03/06 trajectory_ola modeling
;;;  29/05/06 cga: adaptation/conversion filter
;;;  19/12/07 cgv: viterbi based clustering
;;;  01/08/08 move_labels: iterative move segment/state labels based
;;;           on build models
;;;  20/12/08 prune frame (dumping 5-10% gives same quality)
;;;  13/02/09 multimodel -- averaged separate static and delta models
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require_module 'clunits)  ;; C++ modules support
(require 'clunits)         ;; run time scheme support
(require 'clunits_build)   ;; Mostly similar to non-parametric clustering

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  ClusterGen build stuff
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(set! cluster_feature_filename "mcep.desc")
;(set! cluster_feature_filename "mceptraj.desc")
(defvar cg_predict_unvoiced t)
(defvar clustergen_mcep_trees nil)
(defvar cg::trajectory_ola nil)
(defvar cg::generate_resynth_waves t)  ;; during cg_test
(defvar cg:mcep_clustersize 50)
(defvar cg:vuv_predict_dump nil)

(defvar cg:vuv nil) ;; superseded by the v coefficient
(defvar cg:prune_frame_threshold 0.0)
(defvar cg:multimodel nil) ;; for separated static/delta models
(defvar cg:mixed_excitation nil)
(defvar cg:ml_ignore_dur nil)

(defvar cg:parallel_tree_build nil)

(defvar fileid "")

(if cg:vuv_predict_dump
    (set! cg_vuv_predict_features
          (append
           '(lisp_v_value p.lisp_v_value n.lisp_v_value lisp_mcep_0
             n.lisp_mcep_0 p.lisp_mcep_0 lisp_mcep_1 n.lisp_mcep_1 
             p.lisp_mcep_1 lisp_mcep_2 n.lisp_mcep_2 p.lisp_mcep_2)
           (cdr (mapcar car (car (load "festival/clunits/f0.desc" t)))))))


(define (build_clustergen file)
  "(build_clustergen file)
Build cluster synthesizer for the given recorded data and domain."
  (set! datafile file)
  (build_clunits_init file)
  (do_clustergen file)
)

(set! actualSystem system)
(set! cg:parallelSystemCommandList nil)

(define (parallelSystemStore str)
  "Stores command in a global list that will be executed later with parallelSystemFlush"
  ;; Note we put these on the front of the list
  ;; This means the "large" trees get build first which means long wagon
  ;; builds don't wait until the end (which could mean trailing jobs)
  (set! cg:parallelSystemCommandList
        (cons str cg:parallelSystemCommandList))
  t)

(define (parallelSystemFlush)
  (let ((tfn (make_tmp_filename)))
    (set! psfd (fopen tfn "w"))
    (mapcar
     (lambda (s) (format psfd "%s\n" s))
     cg:parallelSystemCommandList)
    (fclose psfd)
;   (set! command (format nil "cat %s | xargs -d '\\n' -n 1 -P `./bin/find_num_available_cpu` sh -c\n" tfn))
    (set! command (format nil "cat %s | tr '\\n' '\\0' | xargs -0 -n 1 -P `./bin/find_num_available_cpu` sh -c" tfn))
    (actualSystem command)
    (delete-file tfn)
    (set! cg:parallelSystemCommandList nil)
    )
  t)

(define (do_clustergen datafile)
  (let ()

    (set_backtrace t)
    (format t "Setting clustergen params\n")
    (set! clustergen_params 
          (append
           (list
            '(clunit_relation mcep)
;            '(clunit_name_feat lisp_cg_name)
;           '(wagon_cluster_size_mcep 50) ;; 50 70 normally
            (list 'wagon_cluster_size_mcep cg:mcep_clustersize) ;; 50 70 normally
            '(wagon_cluster_size_f0 200)   ;; 200
            '(cg_ccoefs_template "ccoefs/%s.mcep")
;            '(cg_ccoefs_template "hnm/%s.hnm")  ;; HNM
            )
           clunits_params))

    ;; New technique that does it utt by utt
    (set! cg::unittypes nil)
    (set! cg::durstats nil)
    (set! cg::unitid 0)

    (set! file_number 0)
    (format t "Setting up numbered_files\n")
    (set! numbered_files
          (mapcar
           (lambda (f)
             (let ((fn (list f file_number)))
               (set! ccc (track.load 
                          (format 
                           nil 
                           (get_param 'cg_ccoefs_template 
                                      clustergen_params 
                                      "ccoefs/%s.mcep")
                           f)))
               (set! file_number (+ (track.num_frames ccc) 5 file_number))
               fn)
             )
           (cadr (assoc 'files clustergen_params))))

    ;; Dump features and vectors -- may be done in parallel
    (format t "Feature dump\n")
    (if cg:parallel_tree_build
        (clustergen::parallel_process_utts numbered_files clustergen_params)
        (clustergen::process_utts numbered_files))

    ;; Build three models

;    ;; Duration model
;    (format t "Building duration model\n")
;    (clustergen::extract_unittype_dur_files datafile cg::unittypes)
;    (clustergen::do_dur_clustering
;     (mapcar car cg::unittypes) clustergen_params cg_build_tree)
;    (clustergen:collect_trees cg::unittypes clustergen_params "dur")

    (set! f0_desc_fd (fopen "festival/clunits/f0.desc" "wb"))
    (pprintf
     (cons '(f0 float) 
            (cdr (car (load "festival/clunits/mcep.desc" t))))
     f0_desc_fd)
    (fclose f0_desc_fd)

    (clustergen::extract_unittype_all_files datafile cg::unittypes)
    (set! cg::unittypes
          (mapcar 
           (lambda (u) (list (string-append u))) ;; unittypes as strings
           (load "festival/disttabs/unittypes" t)))

;    (clustergen::extract_unittype_f0_files datafile cg::unittypes)

    ;; F0 model
    (format t "Building F0 model\n")
    (clustergen::do_clustering
     cg::unittypes clustergen_params 
     clustergen_build_f0_tree "f0")
    (clustergen:collect_trees cg::unittypes clustergen_params "f0")

    (cond
     ((consp cg:multimodel)  ;; list of models to build
      (mapcar
       (lambda (x)
         (format t "Build multimodels: %s\n" (car x))
         (set! cg::cluster_feats (format nil "-track_feats %s" (cadr x)))
         (clustergen::do_clustering 
          cg::unittypes clustergen_params 
          clustergen_build_mcep_tree (car x))
         (clustergen:collect_mcep_trees cg::unittypes clustergen_params (car x)))
       cg:multimodel))
     (cg:multimodel  ;; old static plus dynamic
          ;; Build separate static and delta models
          ;; statics
          (format t "Building multimodels: static \n")
          (set! cg::cluster_feats "-track_feats 1-25")
          (clustergen::do_clustering 
           cg::unittypes clustergen_params 
           clustergen_build_mcep_tree "mcep_static")
          (clustergen:collect_mcep_trees cg::unittypes clustergen_params "mcep_static")
;          (mapcar  ;; for each coefficient (wasn't better)
;           (lambda (x)
;             (set! cg::cluster_feats (format nil "-track_feats %s" x))
;             (clustergen::do_clustering 
;              cg::unittypes clustergen_params 
;              clustergen_build_mcep_tree (format nil "mcep_%s" x))
;             (clustergen:collect_mcep_trees 
;              cg::unittypes clustergen_params 
;              (format nil "mcep_%s" x))
;             )
;           '(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25))

          ;; deltas
          (format t "Building multimodels: deltas \n")
          (set! cg::cluster_feats "-track_feats 26-50")
          (clustergen::do_clustering 
           cg::unittypes clustergen_params 
           clustergen_build_mcep_tree "mcep_deltas")
          (clustergen:collect_mcep_trees cg::unittypes clustergen_params "mcep_delta")

          (if cg:mixed_excitation
              (begin
                ;; str
                (format t "Building multimodels: str \n")
                (set! cg::cluster_feats "-track_feats 51-55")
                (clustergen::do_clustering 
                 cg::unittypes clustergen_params 
                 clustergen_build_mcep_tree "str")
                (clustergen:collect_mcep_trees cg::unittypes clustergen_params "str")))
          )
     (t ;; Build joint spectral models (the older way)
      (format t "Building spectral model\n")
;; was for PCA     (set! cg::cluster_feats "-track_feats 51-75")
      (if cg:deltas
          (set! cg:delta_factor 2)
          (set! cg:delta_factor 1))
      (if cg:mixed_excitation
          (set! cg::cluster_feats 
                (format nil "-track_feats 1-%d" 
                   (+ (* cg:delta_factor mcep_length) 5))) ;; with str, w/o v
          (set! cg::cluster_feats 
                (format nil "-track_feats 1-%d" 
                   (* cg:delta_factor mcep_length)))) ;; w/o v
      (format t "Do clustering\n")
      (clustergen::do_clustering 
       cg::unittypes clustergen_params 
       clustergen_build_mcep_tree "mcep")
      (format t "Collect trees\n")
      (clustergen:collect_mcep_trees cg::unittypes clustergen_params "mcep")
      ))

    (format t "Tree models and vector params dumped\n")
    
  )
)

(define (clustergen::process_utts numbered_files)
  ;; This is pulled out in order to allow numbered_files to be split over
  ;; multiple processors
  (mapcar
   (lambda (f)
     (format t "%s Processing\n" (car f))
     (set! track_info_fd 
           (fopen (format nil "festival/coeffs/%s.mcep" (car f)) "w"))
     (set! feat_info_fd 
           (fopen (format nil "festival/coeffs/%s.feats" (car f)) "w"))
     (unwind-protect
      (begin
        (set! utt (utt.load nil (format nil "festival/utts/%s.utt" (car f))))
        (set! fileid (car f))
        (clustergen::load_hmmstates_utt utt clustergen_params)
        (clustergen::load_ccoefs_utt utt clustergen_params)
        ;; prune_frames: not very useful - off by default
        (if (> cg:prune_frame_threshold 0.0)
            (clustergen::score_frames (car f) utt clustergen_params))

        ;; (clustergen::collect_prosody_stats utt clustergen_params)
        (utt.save utt (format nil "festival/utts_hmm/%s.utt" (car f)))
        (clustergen::name_units_para utt (cadr f) clustergen_params)
        (clustergen::dump_vectors_and_feats_utt utt clustergen_params))
      )
     (fclose track_info_fd)
     (fclose feat_info_fd)
     t
     )
   numbered_files)
  )

(define (clustergen::parallel_process_utts numbered_files clustergen_params)
  ;; Dump the list of files and call the parallelizing script on
  ;; the partitioning of the list of files
  (let ((tfn (make_tmp_filename)))

    (set! fpd (fopen tfn "w"))
    (mapcar
     (lambda (fn) (format fpd "%l\n" fn))
     numbered_files)
    (fclose fpd)

    (set! cgpd (fopen "tmp_cgp.scm" "w"))
    (mapcar
     (lambda (fn) (format cgpd "%l\n" fn))
     clustergen_params)
    (fclose cgpd)

    (system (format nil "./bin/do_clustergen parallel process_utts %s" tfn))

    (delete-file tfn)
    (delete-file "tmp_cgp.scm")

    )
)

(define (clustergen::do_process_utts filename)
  ;; We'll get called again for each partition of the filelist
  ;; We dump the features and vectores for each utt in the filelist
  ;; and do nothing else.
  ;; The clustergen_params should have been dumped in tmp_cgp.scm
  (set! ddd (load filename t))
  (set! clustergen_params (load "tmp_cgp.scm" t))
  (clustergen::process_utts 
   (load filename t)
   )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  clunits (as clunits but on the HMMState relation)
;;;  INCOMPLETE/UNTESTED
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (do_clunits datafile)
  (let ()

    (set_backtrace t)
    (set! clustergen_params 
          (append
           (list
            '(clunit_relation mcep)
            '(wagon_cluster_size_mcep 50) ;; 70 normally
            '(wagon_cluster_size_f0 200)
            '(cg_ccoefs_template "ccoefs/%s.mcep")
;            '(cg_ccoefs_template "hnm/%s.hnm")  ;; HNM
            )
           clunits_params))

    ;; New technique that does it utt by utt
    (set! cg::unittypes nil)
    (set! cg::durstats nil)
    (set! cg::unitid 0)

    (mapcar
     (lambda (f)
       (format t "%s clunit Processing\n" f)
       (set! feat_info_fd 
             (fopen (format nil "festival/coeffs/%s.feats" f) "w"))
       (unwind-protect
        (begin
          (set! utt (utt.load nil (format nil "festival/utts/%s.utt" f)))
          (clustergen::load_hmmstates_utt utt clustergen_params)
          (clustergen::load_ccoefs_utt utt clustergen_params)
          (clustergen::collect_prosody_stats utt clustergen_params)
          (utt.save utt (format nil "festival/utts_hmm/%s.utt" f))
          (clustergen::name_units utt clustergen_params)
          (clustergen::dump_vectors_and_feats_utt utt clustergen_params))
        )
       (fclose track_info_fd)
       (fclose feat_info_fd)
       t
       )
     (cadr (assoc 'files clustergen_params)))

    ;; Build three models

;    ;; Duration model
;    (format t "Building duration model\n")
;    (clustergen::extract_unittype_dur_files datafile cg::unittypes)
;    (clustergen::do_dur_clustering
;     (mapcar car cg::unittypes) clustergen_params cg_build_tree)
;    (clustergen:collect_trees cg::unittypes clustergen_params "dur")

    (set! f0_desc_fd (fopen "festival/clunits/f0.desc" "wb"))
    (pprintf
     (cons '(f0 float) 
            (cdr (car (load "festival/clunits/mcep.desc" t))))
     f0_desc_fd)
    (fclose f0_desc_fd)

    (format t "Extracting features by unittype\n")
    (clustergen::extract_unittype_all_files datafile cg::unittypes)

;    (clustergen::extract_unittype_f0_files datafile cg::unittypes)

    ;; F0 model
    (format t "Building F0 model\n")
    (clustergen::do_clustering
     cg::unittypes clustergen_params 
     clustergen_build_f0_tree "f0")
    (clustergen:collect_trees cg::unittypes clustergen_params "f0")

    ;; Spectral model
    (format t "Building spectral model\n")

;    (clustergen::extract_unittype_mcep_files datafile cg::unittypes)

    (clustergen::do_clustering 
     cg::unittypes clustergen_params 
     clustergen_build_mcep_tree "mcep")
    (clustergen:collect_mcep_trees cg::unittypes clustergen_params "mcep")

    (format t "Tree models and vector params dumped\n")
    
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  trajectory and trajectory_ola build
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (build_clustergen_traj file)
  "(build_clustergen_traj file)
Build cluster synthesizer for the given recorded data and domain:
trajectory model."
  (set! datafile file)
  (build_clunits_init file)
  (do_clustergen_traj file)
)

(define (do_clustergen_traj datafile)
  (let ()

    (set_backtrace t)
    (set! cg::trajectory t)
;    (set! cg::trajectory_ola nil)
    (set! clustergen_mcep_trees '((cg::trajectory t)))
    (if cg::trajectory_ola
        (set! clustergen_mcep_trees 
              (append clustergen_mcep_trees
                      '((cg::trajectory_ola t)))))
    (set! clustergen_params 
          (append
           (list
            '(clunit_relation HMMstate)
            '(wagon_cluster_size_mcep 10)
            '(wagon_cluster_size_f0 20)
            )
           clunits_params))

    ;; Do processing utt by utt to keep memory requirements small
    (set! cg::unittypes nil)
    (set! cg::durstats nil)
    (set! cg::unitid 0)
    (set! cg::global_frame_pos 0)

    (mapcar
     (lambda (f)
       (format t "%s Processing trajectories\n" f)
       (set! track_info_fd 
             (fopen (format nil "festival/coeffs/%s.mcep" f) "w"))
       (set! feat_info_fd 
             (fopen (format nil "festival/coeffs/%s.feats" f) "w"))
       (unwind-protect
        (begin
          (set! utt (utt.load nil (format nil "festival/utts/%s.utt" f)))
          (clustergen::load_hmmstates_utt utt clustergen_params)
          (clustergen::load_ccoefs_utt utt clustergen_params)
          (clustergen::collect_prosody_stats utt clustergen_params)
          (utt.save utt (format nil "festival/utts_hmm/%s.utt" f))
          (clustergen_traj::name_units utt clustergen_params)
          (clustergen_traj::dump_vectors_and_feats_utt utt clustergen_params))
        )
       (fclose track_info_fd)
       (fclose feat_info_fd)
       t
       )
     (cadr (assoc 'files clustergen_params)))

    ;; Build three models

;    ;; Duration model
;    (format t "Building duration model\n")
;    (clustergen::extract_unittype_dur_files datafile cg::unittypes)
;    (clustergen::do_dur_clustering
;     (mapcar car cg::unittypes) clustergen_params cg_build_tree)
;    (clustergen:collect_trees cg::unittypes clustergen_params "dur")

    (set! f0_desc_fd (fopen "festival/clunits/f0.desc" "wb"))
    (pprintf
     (cons '(f0 float) 
            (cdr (car (load "festival/clunits/mcep.desc" t)))
            )
     f0_desc_fd)
    (fclose f0_desc_fd)

    (format t "Extracting features by unittype\n")
    (clustergen::extract_unittype_all_files_traj datafile cg::unittypes)

;    (clustergen::extract_unittype_f0_files datafile cg::unittypes)

    ;; F0 model
;    (format t "Building F0 model\n")
;    (clustergen::do_clustering
;     cg::unittypes clustergen_params 
;     clustergen_build_f0_tree "f0")
;    (clustergen:collect_trees cg::unittypes clustergen_params "f0")

    ;; Spectral model
    (format t "Building trajectory spectral model\n")

;    (clustergen::extract_unittype_mcep_files datafile cg::unittypes)

    (clustergen::do_clustering 
     cg::unittypes clustergen_params 
     clustergen_build_mcep_trajectory_tree "mcep")

    (clustergen:collect_mcep_trajectory_trees cg::unittypes clustergen_params)

    (format t "Tree models and trajectory params dumped\n")
    
  )
)

(define (cg_remove_featdescs l rfl)
  (cond
   ((null l) l)
   ((string-equal (car rfl) (caar l))
    (cdr l))
   (t
    (cons (car l) (cg_remove_featdescs (cdr l) rfl))))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  prune frames
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar xxx nil)

(define (clustergen::score_frames name utt clustergen_params)
  (set! old_cg_predict_unvoiced cg_predict_unvoiced)
  (set! cg_predict_unvoiced nil)
;  (set! old_cg_mlpg cg:mlpg)
;  (set! cg:mlpg nil)
  (format t "%s prune_frames\n" name)

  (set! old_param_track (utt.feat utt "param_track"))

  (set! real_track 
        (track.load 
         (format 
          nil
          (get_param 'cg_ccoefs_template clustergen_params "ccoefs/%s.mcep")
          name)))
  
  (if (assoc 'cg::trajectory clustergen_mcep_trees)
      (ClusterGen_predict_trajectory utt) ;; predict trajectory
      (ClusterGen_predict_mcep utt) ;; predict vector types
      )

  (set! xxx (cons (utt.feat utt "param_track") xxx))
  (set! sn 0)

  (mapcar 
   (lambda (m)
     ;; mcep frame
     (set! sn (+ 1 sn))
     (set! fp (item.feat m "frame_number"))
     (set! p (item.feat m "clustergen_param_frame"))
     
     (set! score (pf_mcep_distance 
                  real_track fp
                  clustergen_param_vectors p))
     
     (item.set_feat m "cg_score" score)
     (format t "cg_score %s %f\n" (item.name m) score)
     t
     )
   (utt.relation.items utt 'mcep)
   )

  (utt.set_feat utt "param_track" old_param_track)
;  (set! cg:mlpg old_cg_mlpg)
;  (set! cg_predict_unvoiced old_cg_predict_unvoiced )
  t
)

(define (ClusterGen_prune_frames filename testdir)
  ;; Tests from natural durations

  (set! old_cg_predict_unvoiced cg_predict_unvoiced)
  (set! cg_predict_unvoiced nil)
  (set! cg:mlpg nil)
  ;; I keep the param_tracks in a global list otherwise gc causes a crash
  ;; this is a work around solution, but far from correct
  (set! xxx nil)
  (mapcar 
   (lambda (x)
     (format t "CG prune_frames %s\n" (car x))
     (gc)
     (set! real_track 
           (track.load 
            (format 
             nil
             (get_param 'cg_ccoefs_template clustergen_params "ccoefs/%s.mcep")
             (car x))))
     (set! utt1 (utt.load nil (format nil "festival/utts/%s.utt" (car x))))
     (clustergen::load_hmmstates_utt utt1 clustergen_params)
     (clustergen::load_ccoefs_utt utt1 clustergen_params)
     (if (assoc 'cg::trajectory clustergen_mcep_trees)
        (ClusterGen_predict_trajectory utt1) ;; predict trajectory
        (ClusterGen_predict_mcep utt1) ;; predict vector types
;        (ClusterGen_acoustic_predict_mcep utt1 real_track) 
        )

     ;;; keep these in core as weird thing happen if they are gc'd
     (set! xxx (cons (utt.feat utt1 "param_track") xxx))
     (set! sn 0)
     (mapcar 
      (lambda (m)
        ;; mcep frame
        (set! sn (+ 1 sn))
        (set! fp (item.feat m "frame_number"))
        (set! p (item.feat m "clustergen_param_frame"))

        (set! score (pf_mcep_distance 
                     real_track fp
                     clustergen_param_vectors p))

        (item.set_feat m "cg_score" score)
        (format t "cg_score %s %f\n" (item.name m) score)
        t
        )
      (utt.relation.items utt1 'mcep)
      )
     (utt.save utt1 (format nil "festival/utts_hmmS/%s.utt" (car x)))

     t)
   (load filename t))
  (set! cg_predict_unvoiced old_cg_predict_unvoiced)
  t)

(define (pf_mcep_distance t1 p1 t2 p2)
  "(pf_mcep_distance t1 p1 t2 p2)
Find distance of t1.p1 wrt t2.p2 (with std)."
  ;; statics and no sd (this is close to MCD)
  ;; ignore F0 deltas and voicing
  ;; tried lots of things measurements and this seems reasonable
  (let ((nc (track.num_channels t1))
        (c 1)
        (zd 0)
        (score 0))
    ;; Try to add voicing -- but it didn't help
    (set! zd (- (track.get t1 p1 51)
                (track.get t2 p2 102)))
;    (format t "voicings %f %f\n"
;            (track.get t1 p1 51) (track.get t2 p2 102))
    (set! score (* zd zd))
'    (while (< c (/ nc 2))
           (set! zd (/ (- (track.get t1 p1 c) 
                          (track.get t2 p2 (* c 2)))
                       1
;                       ;; or standard deviation (not so good)
;                       (track.get t2 p2 (+ 1 (* c 2)))
                       ))
           (set! score (+ score (* zd zd)))
           (set! c (+ 1 c))
           )
    (/ score c)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  ml: move labels based on predictions
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (ClusterGen_move_labels filename testdir)
  ;; Tests from natural durations

  (set! old_cg_predict_unvoiced cg_predict_unvoiced)
  (set! cg_predict_unvoiced nil)
  (set! cg:mlpg nil)
  ;; I keep the param_tracks in a global list otherwise gc causes a crash
  ;; this is a work around solution, but far from correct
  (set! xxx nil)
  (mapcar 
   (lambda (x)
     (format t "CG move_labels %s\n" (car x))
     (gc)
     (set! real_track 
           (track.load 
            (format 
             nil
             (get_param 'cg_ccoefs_template clustergen_params "ccoefs/%s.mcep")
             (car x))))
     (set! utt1 (utt.load nil (format nil "festival/utts/%s.utt" (car x))))
     (clustergen::load_hmmstates_utt utt1 clustergen_params)
     (clustergen::load_ccoefs_utt utt1 clustergen_params)
     (if (assoc 'cg::trajectory clustergen_mcep_trees)
        (ClusterGen_predict_trajectory utt1) ;; predict trajectory
        (ClusterGen_predict_mcep utt1) ;; predict vector types
;        (ClusterGen_acoustic_predict_mcep utt1 real_track) 
        )
;     (utt.relation.load utt1 "HMMstateN"
;                        (format nil "lab/%s.sl" (utt.feat utt1 "fileid")))
     ;;; keep these in core as weird thing happen if they are gc'd
     (set! xxx (cons (utt.feat utt1 "param_track") xxx))
     (set! sn 0)
     (mapcar 
      (lambda (s)
        ;; hmm state
        (set! sn (+ 1 sn))
        (if (and (item.next s)
                 t
;                 (< (item.feat s "end")
;                    (track.get_time 
;                     real_track
;                     (- (track.num_frames real_track) 1)))
                 )
            (begin
              ;; The parties of interest
              (set! fp (item.feat s "R:mcep_link.daughtern.frame_number"))
              (set! p (item.feat s "R:mcep_link.daughtern.clustergen_param_frame"))
              (set! nfp (item.feat s "n.R:mcep_link.daughter1.frame_number"))
              (set! np (item.feat s "n.R:mcep_link.daughter1.clustergen_param_frame"))
              (set! durp (ml_dur_score s))
              (if (item.next s)
                  (set! ndurp (ml_dur_score (item.next s)))
                  (set! ndurp (* -1 durp)))
              (set! durt (* durp ndurp))

              ;; The current distances, and if-moved distances
              (set! d1 (ml_mcep_distance 
                        real_track fp clustergen_param_vectors p))
              (set! d2 (ml_mcep_distance 
                        real_track nfp clustergen_param_vectors np))
              (set! dm1 (ml_mcep_distance 
                         real_track fp clustergen_param_vectors np))
              (set! dm2 (ml_mcep_distance 
                         real_track nfp clustergen_param_vectors p))
              (format t "%s %f %f %f %f\n"
                      (item.name s) d1 d2 dm1 dm2)
              ;; See if a move is worth it
              (cond
               ((and t (< dm1 d1)
                     (if cg:ml_ignore_dur
                         t
                         (and (<= durt 0) (>= durp 0)))
                     (< (item.feat s "p.end")
                        (- (item.feat s "end") 0.006)))
                ;; Move end towards beginning of file
                (item.set_feat s "end" (- (item.feat s "end") 0.005))
                (if (null (item.relation.next s "segstate")) ;; if final state
                    (item.set_feat                 ;; move seg end too
                     (item.relation.parent s "segstate") "end" 
                     (item.feat s "end")))             
                (format t "   %s_%s_%d move boundary -0.005\n" 
                        (car x) (item.name s) sn)
                )
               ((and t (< dm2 d2)
                     (if cg:ml_ignore_dur
                         t
                         (and (<= durt 0) (>= durp 0)))
                     (> (item.feat s "n.end")
                        (+ (item.feat s "end") 0.006)))
                ;; Move end towards end of file
                (item.set_feat s "end" (+ (item.feat s "end") 0.005))
                (if (null (item.relation.next s "segstate")) ;; if final state
                    (item.set_feat                ;; move seg end too
                     (item.relation.parent s "segstate") "end" 
                     (item.feat s "end")))
                (format t "   %s_%s_%d move boundary +0.005\n" 
                        (car x) (item.name s) sn )
                )
               )
              ))
        t
        )
      (utt.relation.items utt1 'HMMstate)
      )
     (ml.simple.save.relation
      utt1 "HMMstate"
      (format nil "%s/%s.sl" testdir (utt.feat utt1 "fileid")))
     (ml.simple.save.relation
      utt1 "Segment"
      (format nil "%s/%s.lab" testdir (utt.feat utt1 "fileid")))
     t)
   (load filename t))
  (set! cg_predict_unvoiced old_cg_predict_unvoiced)
  t)

(require 'cart_aux)

(define (ml_dur_score s)
  (let ((d (item.feat s "lisp_cg_duration"))
        (pzdur (wagon_predict s duration_cart_tree_cg))
        (ph_info (assoc_string (item.name s) duration_ph_info_cg))
        (azdur 0)
        (x 0))

    (set! azdur (/ (- d (car (cdr ph_info)))
                   (car (cdr (cdr ph_info)))))
    (cond
     ((string-matches (item.name s) "pau_.*")
      (set! x 0) ;; doesn't matter
      )
     ((< azdur pzdur)
      (set! x -1)
      (set! x (- azdur pzdur))
      )  ;; its smaller than we want
     ((> azdur pzdur)
      (set! x 1)
      (set! x (- azdur pzdur))
      )   ;; its larger than we want
     (t
      (set! x 0))) ;; just right
;    (format t "dur %s a %f az %f pz %f %l x %d\n"
;            (item.name s) d azdur pzdur ph_info x)
    x)
)

(define (ml.simple.save.relation u rel fname)
  (set! fd (fopen fname "w"))
  (format fd "#\n")
  (mapcar
   (lambda (s)
     (if (and (string-equal rel "HMMstate")
              (string-matches (item.name s) ".*_.*"))
         (format fd "%0.3f 125 %s %s\n" (item.feat s "end") 
                 (string-after (item.name s) "_") (string-before (item.name s) "_") )
         (format fd "%0.3f 125 %s\n" (item.feat s "end") (item.name s))))
   (utt.relation.items u rel))
  (fclose fd)
  t)

(define (ml_mcep_distance t1 p1 t2 p2)
  "(ml_mcep_distance t1 p1 t2 p2)
Find distance of t1.p1 wrt t2.p2 (with std)."
  ;; statics and no sd (this is close to MCD)
  ;; ignore F0 deltas and voicing
  ;; tried lots of things measurements and this seems reasonable
  (let ((nc (track.num_channels t1))
        (c 1)
        (zd 0)
        (score 0))
    ;; Try to add voicing -- but it didn't help
;    (set! zd (- (track.get t1 p1 51)
;                (track.get t2 p2 102)))
;    (set! score (* zd zd 5.0))
    (while (< c 50)  ;; Aug 2011 -- better to opt on static+delta 
           (set! zd (/ (- (track.get t1 p1 c) 
                          (track.get t2 p2 (* c 2)))
                       1
                       ;; or standard deviation (not so good)
;                       (track.get t2 p2 (+ 1 (* c 2)))
                       ))
           (set! score (+ score (* zd zd)))
           (set! c (+ 1 c))
           )
    score))

(define (ClusterGen_ml_delete_short_pauses ttdfile indir outdir)

  (mapcar
   (lambda (f)
     (set! utt1 (Utterance Text ""))
     (utt.relation.load 
      utt1' "Segment"
      (format nil "%s/%s.lab" indir (car f)))
     (utt.relation.load 
      utt1' "HMMstate"
      (format nil "%s/%s.sl" indir (car f)))
     (set! seg (utt.relation.first utt1 "Segment"))
     (set! state (utt.relation.first utt1 "HMMstate"))
     (set! seg_number 0)
     (while seg
      (set! nseg (item.next seg))
      (set! seg_number (+ 1 seg_number))
      (if (and  ;; delete short silences
           (string-equal "pau" (item.name seg))
           (< (item.feat seg "duration") 0.015))
          (begin  ;; delete it and the states with it
            (format t "deleting %s_pau_%s\n" (car f) seg_number)
            (while (and state (< (item.feat state "end") 
                                 (+ 0.001 (item.feat seg "end"))))
             (set! nstate (item.next state))
             
             (item.delete state)
             (set! state nstate))
            (item.delete seg)
            )
          (begin
            (while (and state (< (item.feat state "end") 
                                 (+ 0.001 (item.feat seg "end"))))
             (set! nstate (item.next state))
             ;; just move -- no delete
             (set! state nstate)))
          )
      (set! state nstate)
      (set! seg nseg))

     (ml.simple.save.relation
      utt1 "HMMstate"
      (format nil "%s/%s.sl" outdir (car f)))
     (ml.simple.save.relation
      utt1 "Segment"
      (format nil "%s/%s.lab" outdir (car f)))
     t
     )
   (load ttdfile t))
  t
)

(define (find_new_end utt)

  (set! last_seg (utt.relation.last utt 'Segment))
  (while (and last_seg (string-equal "pau" (item.feat last_seg "name")))
         (set! last_seg (item.prev last_seg)))
  (if (> (+ 0.250 (item.feat last_seg "p.end")) (item.feat last_seg "end"))
      (item.feat last_seg "end")
      (+ 0.250 (item.feat last_seg "p.end"))))

(define (find_new_start utt)

  (set! first_seg (utt.relation.first utt 'Segment))
  (while (and first_seg (string-equal "pau" (item.feat first_seg "name")))
         (set! first_seg (item.next first_seg)))
  (if (> (item.feat first_seg "p.end") 0.250)
      (- (item.feat first_seg "p.end") 0.250)
      0.0))

(define (pau_triming filename)
  (mapcar 
   (lambda (f)
     (set! utt1 (utt.load nil (format nil "festival/utts/%s.utt" (car f))))
     (set! fff (car f))
     (set! new_end (find_new_end utt1))
     (set! new_start (find_new_start utt1))
     (format t "%s %f %f\n" (car f) new_start new_end)
     t
     )
   (load filename t))
  t)

(define (ClusterGen_move_means datafile newmeansfile)
  ;; Tests from natural durations

  (set! old_cg_predict_unvoiced cg_predict_unvoiced)
  (set! cg_predict_unvoiced nil)
  (set! cg:mlpg nil)
  (set! new_clustergen_param_vectors (track.copy clustergen_param_vectors))
  ;; I keep the param_tracks in a global list otherwise gc causes a crash
  ;; this is a work around solution, but far from correct
  (set! xxx nil)
  (mapcar 
   (lambda (x)
     (format t "CG move_means %s\n" (car x))
     (gc)
     (set! real_track 
           (track.load 
            (format 
             nil
             (get_param 'cg_ccoefs_template clustergen_params "ccoefs/%s.mcep")
             (car x))))
     (set! utt1 (utt.load nil (format nil "festival/utts/%s.utt" (car x))))
     (clustergen::load_hmmstates_utt utt1 clustergen_params)
     (clustergen::load_ccoefs_utt utt1 clustergen_params)
     (if (assoc 'cg::trajectory clustergen_mcep_trees)
        (ClusterGen_predict_trajectory utt1) ;; predict trajectory
        (ClusterGen_predict_mcep utt1) ;; predict vector types
;        (ClusterGen_acoustic_predict_mcep utt1 real_track) 
        )
     ;;; keep these in core as weird thing happen if they are gc'd
     (set! xxx (cons (utt.feat utt1 "param_track") xxx))
     (set! fn 0)
     (mapcar 
      (lambda (frame)
        ;; each mcep frame
        (set! fn (+ 1 fn))
        (set! f (item.feat frame "R:mcep_link.parent.clustergen_param_frame"))
        (set! j 0)
        (while (< j nc)
           (set! d (- (track.get real_track fn j)
                      (track.get clustergen_param_vectors f j)))
           ;; do something !
           (set! j (+ 1 j)))
        )
      (utt.relation.items utt1 'mcep)
      )
     t)
   (load datafile t))

  (track.save new_clustergen_param_vectors newmeansfile)
  (set! cg_predict_unvoiced old_cg_predict_unvoiced)
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  cgv: viterbi based prediction
;;;       Didn't help (Dec 2007)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (cgv_label_clustergen datafile odir)
  (mapcar
   (lambda (d)
     (format t "%s cgv_label\n" (car d))
     (set! utt (utt.load nil (format nil "festival/utts/%s.utt" (car d))))
     ;; We could get the timings from the utt, but to be safest we take
     ;; them directly from the existing mcep file
     (set! track_mcep (track.load (format nil "mcep/%s.mcep" (car d))))
     ;;; Synth the frames with current models
     (clustergen::load_hmmstates_utt utt clustergen_params)
     (clustergen::load_ccoefs_utt utt clustergen_params)
     (if (assoc 'cg::trajectory clustergen_mcep_trees)
        (ClusterGen_predict_trajectory utt) ;; predict trajectory
        (ClusterGen_predict_mcep utt) ;; predict vector types
        )
     ;;; Make track file of cluster names
     (set! num_frames (track.num_frames track_mcep))
     (set! c_track (track.resize nil num_frames 1))
     (set! i 0)
     (mapcar
      (lambda (frame)
        (track.set_time c_track i (track.get_time track_mcep i))
        (track.set c_track i 0 (item.feat frame "clustergen_param_frame"))
        (set! i (+ 1 i)))
      (utt.relation.items utt "mcep"))
     (track.save c_track (format nil "cgv/lab/%s.cseq" (car d)))
     )
   (load datafile t))
)

(define (build_cgv_clustergen file)
  "(build_clustergen file)
Build cluster synthesizer for the given recorded data and domain."
  (set! datafile file)
  (build_clunits_init file)
  (do_clustergen_cgv file)
)

(define (do_clustergen_cgv datafile)
  (let ()

    (set_backtrace t)
    (set! clustergen_params 
          (append
           (list
            '(clunit_relation mcep)
            '(wagon_cluster_size_mcep 50) ;; 70 normally
            '(wagon_cluster_size_f0 200)
            '(cg_ccoefs_template "ccoefs/%s.mcep")
            )
           clunits_params))

    ;; New technique that does it utt by utt
    (set! cg::unittypes nil)
    (set! cg::durstats nil)
    (set! cg::unitid 0)

    (mapcar
     (lambda (f)
       (format t "%s Processing\n" f)
       (set! track_info_fd 
             (fopen (format nil "festival/coeffs/%s.mcep" f) "w"))
       (set! feat_info_fd 
             (fopen (format nil "festival/coeffs/%s.feats" f) "w"))
       (unwind-protect
        (begin
          (set! utt (utt.load nil (format nil "festival/utts/%s.utt" f)))
          (clustergen::load_hmmstates_utt utt clustergen_params)
          (clustergen::load_ccoefs_utt utt clustergen_params)
          (clustergen::collect_prosody_stats utt clustergen_params)
          (utt.save utt (format nil "festival/utts_hmm/%s.utt" f))
          (clustergen::name_units utt clustergen_params)
          (clustergen::dump_vectors_and_feats_utt utt clustergen_params)
          )
        )
       (fclose track_info_fd)
       (fclose feat_info_fd)
       t
       )
     (cadr (assoc 'files clustergen_params)))

    (set! f0_desc_fd (fopen "festival/clunits/f0.desc" "wb"))
    (pprintf
     (cons '(f0 float) 
            (cdr (car (load "festival/clunits/mcep.desc" t))))
     f0_desc_fd)
    (fclose f0_desc_fd)

    (format t "Extracting F0/class and features by unittype\n")
;    (clustergen::extract_unittype_all_files datafile cg::unittypes)
    (system (format nil "$CLUSTERGENDIR/cg_get_feats_all_cgv %s\n" datafile))

    ;; F0 model
    (format t "Building F0 model\n")
    (clustergen::do_clustering
     cg::unittypes clustergen_params 
     clustergen_build_f0_tree "f0")
    (clustergen:collect_trees cg::unittypes clustergen_params "f0")

    ;; Spectral model
    (format t "Building cseq spectral model\n")

    (clustergen::do_clustering 
     cg::unittypes clustergen_params 
     clustergen_build_cseq_tree "cseq")
    (clustergen:collect_cseq_trees cg::unittypes clustergen_params)

    (format t "cseq tree models dumped\n")

  )
)

(define (clustergen_build_cseq_tree unittype cg_params)
"Build tree with Wagon for this unittype."
;; Treat classes as discrete and predict pdf for them
  (let ((command 
	 (format nil "%s %s -desc %s -data '%s' -test '%s' -balance %s -stop %s -output '%s' %s | grep -v '^ ' "
		 (get_param 'wagon_progname cg_params "$ESTDIR/bin/wagon")
;                 "-stepwise -swopt rmse"
                 ""  ;; no stepwise
;                 (get_param 'wagon_field_desc cg_params "wagon")
                 (format nil "festival/clunits/cseq_%s.desc" unittype)
                 (format nil "festival/feats/%s_class.feats" ;; .train
                         unittype)
                 (format nil "festival/feats/%s_class.feats" ;; .test
                         unittype)
		 (get_param 'wagon_balance_size cg_params 0)
		 (get_param 'wagon_cluster_size_mcep cg_params 100)
                 (format nil "festival/trees/%s_cseq.tree" unittype)
		 (get_param 'wagon_other_params cg_params "")
		 )))
;;    Needed if you want to do stepwise
;     (system (format nil
;                     "./bin/traintest %s\n"
; 		 (string-append 
; 		  (get_param 'db_dir cg_params "./")
; 		  (get_param 'feats_dir cg_params "festival/feats/")
; 		  unittype
; 		  (get_param 'feats_ext cg_params ".feats"))))
    ;; Create description file with only the class in the unittype
    (system
     (format nil
             "cat festival/feats/%s_class.feats | awk '{print $1}' | sort -u >cseq.vals" unittype))
    (set! classes (load "cseq.vals" t))
    (set! cseq_desc_fd 
          (fopen (format nil "festival/clunits/cseq_%s.desc" unittype) "wb"))
    (pprintf
     (cons (cons 'class classes)
           (cdr (car (load "festival/clunits/mcep.desc" t))))
     cseq_desc_fd)
    (fclose cseq_desc_fd)

    (format t "%s\n" command)

    (system command)))

(define (clustergen:collect_cseq_trees unittypes params)
"Collect the trees into one file as an assoc list, and dump leafs into
a track file"
  (let ((fd (fopen 
             (format nil "festival/trees/%s_%s.tree"
	      (get_param 'index_name params "all.") "cseq")
	      "wb")))
    (format fd ";; Autogenerated list of clustergen cseq trees\n")
    (mapcar
     (lambda (unit)
       (set! tree (car (load (string-append "festival/trees/"
                                            (car unit) 
                                            "_cseq" 
                                            ".tree") t)))
;;       (set! tree (clustergen::cgv_cseq_tree_simplify tree))
       (pprintf (list (car unit) tree) fd))
     unittypes)
    (format fd "\n")
    (fclose fd)
    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Duration and F0 stats collection
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (get_phone_data phone)
  (let ((a (assoc phone cg::durstats)))
    (if a
	(cadr a)
	(begin ;; first time for this phone
	  (set! cg::durstats
		(cons (list phone (suffstats.new)) cg::durstats))
	  (car (cdr (assoc phone cg::durstats)))))))

(define (duration i)
  ;; for any item
  (if (item.prev i)
      (- (item.feat i "end") (item.feat i "p.end"))
      (item.feat i "end")))

(define (cummulate_duration utt durrelation)

  (mapcar
   (lambda (s)
     (suffstats.add 
      (get_phone_data (item.name s))
      (duration s)))
   (utt.relation.items utt durrelation))
  t)

(define (clustergen::collect_prosody_stats utt params)

  (cummulate_duration utt "HMMstate")

  t
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (clustergen::name_units utt params)
  (let ((cg_name_feat (get_param 'clunit_name_feat params "name"))
        (cg_relation (get_param 'clunit_relation params "Segment")))
    ;; note name_units and dump_vectors_and_feats must traverse
    ;; the units in the same order
;    (set! cg_name_feat "R:mcep_link.parent.R:segstate.parent.name")
    (mapcar
     (lambda (s)
       (let ((cname (item.feat s cg_name_feat)))
         (if (or (string-equal cname "0")
                 (string-equal cname "ignore")
                 (> (item.feat s "cg_score") cg:prune_frame_threshold) ;; prune
                 (if cg:vuv (vuv_mismatch s)) ;; hnm
                 )
             t ;; do nothing
             (begin
               (item.set_feat s "clunit_name" cname)
               (item.set_feat s "unitid" cg::unitid)
               (set! cg::unitid (+ 1 cg::unitid))
               (let ((p (assoc cname cg::unittypes)))
		    (if p
                        (begin
                          (set! occurid (+ 1 (cadr p)))
                          (set-cdr! p (cons occurid nil)))
                        (begin
                          (set! occurid 0)
                          (set! cg::unittypes
			      (cons (list cname occurid) cg::unittypes)))
                        ))
               (item.set_feat s "occurid" occurid)
               ))
         t))
     (reverse (utt.relation.items utt cg_relation))
     )
    t))

(define (clustergen::name_units_para utt file_number params)
  (let ((cg_name_feat (get_param 'clunit_name_feat params "name"))
        (cg_relation (get_param 'clunit_relation params "Segment"))
        (n 0))
    ;; note name_units and dump_vectors_and_feats must traverse
    ;; the units in the same order
    ;; This is now a function without side-effects, for use in the
    ;; the parallel case
;    (set! cg_name_feat "R:mcep_link.parent.R:segstate.parent.name")
    (mapcar
     (lambda (s)
       (let ((cname (item.feat s cg_name_feat)))
         (if (or (string-equal cname "0")
                 (string-equal cname "ignore")
                 (> (item.feat s "cg_score") cg:prune_frame_threshold) ;; prune
                 (if cg:vuv (vuv_mismatch s)) ;; hnm
                 )
             t ;; do nothing
             (begin
               (item.set_feat s "clunit_name" cname)
               (set! occurid (+ file_number n))
               (item.set_feat s "occurid" occurid)
               (set! n (+ 1 n))
               ))
         t))
     (reverse (utt.relation.items utt cg_relation))
     )
    t))

(define (cg_frame_voiced s)
  (if (and (string-equal "-"
            (item.feat 
             s "R:mcep_link.parent.R:segstate.parent.ph_vc"))
           (string-equal "-"
            (item.feat 
             s "R:mcep_link.parent.R:segstate.parent.ph_cvox")))
      0
      1)
)

(define (mcep_51 i)
  (track.get
   (utt.feat (item.get_utt i) "param_track")
   (item.feat i "frame_number")
   51))

(define (vuv_mismatch s)
  ;; Only use vectors where the phonetic voicing agrees with the 
  ;; acoustic voicing
;  (format t "vuv_mismatch %s %d %l %l\n" (item.name s) (item.feat s "frame_number") (mcep_51 s) (cg_frame_voiced s))
  (set! vvv (mcep_51 s))
  (if (< vvv 0.5)
      (set! vvv 0)
      (set! vvv 1))
;  (format t "vuv_mismatch %s %l %l\n" (item.name s) vvv (cg_frame_voiced s))
  (if (string-equal vvv (cg_frame_voiced s))
      nil
      t)
  nil
  )

(define (clustergen::dump_vectors_and_feats_utt utt params)
  (let ((cg_relation (get_param 'clunit_relation params "Segment"))
        (cg_mcep (utt.feat utt "param_track"))
        (feats (car (cdr (assoc 'feats params))))
        (cname "ignore"))
    ;; note name_units and dump_vectors_and_feats must traverse
    ;; the units in the same order
    (set! cg_mcep_channels (track.num_channels cg_mcep))
  (mapcar 
   (lambda (s)
     (set! cname (item.feat s "clunit_name"))
     (if (or (string-equal cname "0")
             (string-equal cname "ignore")
             (> (item.feat s "cg_score") cg:prune_frame_threshold) ;; prune
             (if cg:vuv (vuv_mismatch s)) ;; hnm
             )
         t ;; do nothing
         (begin

           ;; Vector values
           (format track_info_fd "%s " cname)
           (set! frame_number (item.feat s "frame_number"))
           ;; Special deal with f0
           (set! f0_val (track.get cg_mcep frame_number 0))
;           (if (> f0_val 0)
;               (set! norm_f0_val (/ (- f0_val 172.0) 27.0))
;               (set! norm_f0_val -100))
           (format track_info_fd "%f " f0_val)
           
           (set! f 1)
           (while (< f cg_mcep_channels)
              (format track_info_fd "%f "
                      (track.get cg_mcep frame_number f))
              (set! f (+ 1 f)))

           (format track_info_fd "\n")

;           (format t "%s %f\n" ;; awb_debug
;                   (item.name s)
;                   (track.get cg_mcep frame_number 51))

           (format feat_info_fd "%s " cname)
           ;; Feature values
           (mapcar 
            (lambda (f)
              (set! fval (unwind-protect 
                          (item.feat s f)
                          "0"))
              (if (string-matches fval " *")
                  (format feat_info_fd "%l " fval)
                  (format feat_info_fd "%s " fval)))
            feats)
           (format feat_info_fd "\n")
           ))
     t)
   (reverse (utt.relation.items utt cg_relation))
   )
  t)
)

(define (clustergen_traj::name_units utt params)
  (let ((cg_name_feat (get_param 'clunit_name_feat params "name"))
        (cg_relation (get_param 'clunit_relation params "Segment")))
    ;; note name_units and dump_vectors_and_feats must traverse
    ;; the units in the same order
    (mapcar
     (lambda (s)
       (let ((cname (item.feat s cg_name_feat)))
         (if (or (string-equal cname "0")
                 (string-equal cname "ignore")
                 (null (item.relation.daughters s 'mcep_link)))
             t ;; do nothing
             (begin
               (item.set_feat s "clunit_name" cname)
               (item.set_feat s "unitid" cg::unitid)
               (set! cg::unitid (+ 1 cg::unitid))
               (let ((p (assoc cname cg::unittypes))
                     (l 
                      (if (assoc 'cg::trajectory_ola clustergen_mcep_trees)
                          (+ (length (item.relation.daughters s 'mcep_link))
                             2
                             (if (item.prev s)
                                 (length (item.relation.daughters 
                                          (item.prev s) 'mcep_link))
                                 0))
                          (length (item.relation.daughters s 'mcep_link)))))
		    (if p
                        (begin
                          (set! occurid (cadr p))
                          (set-cdr! 
                           p 
                           (cons 
                            (+ l occurid)
                            nil)))
                        (begin
                          (set! occurid 0)
                          (set! cg::unittypes
			      (cons 
                               (list 
                                cname 
                                (+ l occurid))
                               cg::unittypes)))
                        ))
               (item.set_feat s "occurid" occurid)
               ))
         t))
     (reverse (utt.relation.items utt cg_relation))
     )
    t))

(define (clustergen_traj::dump_vectors_and_feats_utt utt params)
  (let ((cg_relation (get_param 'clunit_relation params "Segment"))
        (cg_mcep (utt.feat utt "param_track"))
        (feats (car (cdr (assoc 'feats params))))
        (cname "ignore"))
    ;; note name_units and dump_vectors_and_feats must traverse
    ;; the units in the same order
    (set! cg_mcep_channels (track.num_channels cg_mcep))
  (mapcar 
   (lambda (s)
     (set! cname (item.feat s "clunit_name"))
     (if (or (string-equal cname "0")
             (string-equal cname "ignore")
             (null (item.relation.daughters s 'mcep_link)))
         t ;; do nothing
         (begin
           ;; Vector values
           (item.set_feat s "num_frames" 0)
           (item.set_feat s "global_frame_pos" cg::global_frame_pos)
           (if (assoc 'cg::trajectory_ola clustergen_mcep_trees)
               (begin
                 (if (item.prev s)
                     (set! frames (item.relation.daughters (item.prev s) 'mcep_link))
                     (set! frames nil))
                 (set! num_frames (length frames))
                 (item.set_feat s "num_frames" 
                                (+ (item.feat s "num_frames") num_frames 1))
                 (mapcar
                  (lambda (frame)
                    (set! frame_number (item.feat frame "frame_number"))
                    (set! f 0)
                    (format track_info_fd "%s " cname)
                    (while (< f cg_mcep_channels)
                           (format track_info_fd "%f "
                                   (track.get cg_mcep frame_number f))
                           (set! f (+ 1 f)))
                    (format track_info_fd "\n")
                    (set! cg::global_frame_pos (+ 1 cg::global_frame_pos))
                    )
                  frames)
                 ;; mid point marker
                 (set! f 0)
                 (format track_info_fd "%s " cname)
                 (while (< f cg_mcep_channels)
                           (format track_info_fd "-1.0 ")
                           (set! f (+ 1 f)))
                 (format track_info_fd "\n")
                 (set! cg::global_frame_pos (+ 1 cg::global_frame_pos))
                 ))

           ;; rest of the frames
           (set! frames (item.relation.daughters s 'mcep_link))
           (set! num_frames (length frames))
           (item.set_feat 
            s "num_frames" 
            (+ (item.feat s "num_frames") num_frames 
               (if (assoc 'cg::trajectory_ola clustergen_mcep_trees)
                   1
                   0)))
           (mapcar
            (lambda (frame)
              (set! f 0)
              (set! frame_number (item.feat frame "frame_number"))
              (format track_info_fd "%s " cname)
              (while (< f cg_mcep_channels)
                     (format track_info_fd "%f "
                             (track.get cg_mcep frame_number f))
                     (set! f (+ 1 f)))
              (format track_info_fd "\n")
              (set! cg::global_frame_pos (+ 1 cg::global_frame_pos))
              )
            frames)
           ;; Feature values
           (format feat_info_fd "%s " cname)
           (mapcar 
            (lambda (f)
              (set! fval (unwind-protect (item.feat s f) "0"))
              (if (string-matches fval " *")
                  (format feat_info_fd "%l " fval)
                  (format feat_info_fd "%s " fval)))
            feats)
           (format feat_info_fd "\n")
;           (set! cg::global_frame_pos (+ 1 cg::global_frame_pos))
           (if (assoc 'cg::trajectory_ola clustergen_mcep_trees)
               (begin
                 (set! f 0)
                 (format track_info_fd "%s " cname)
                 (while (< f cg_mcep_channels)
                        (format track_info_fd "-2.0 ")
                        (set! f (+ 1 f)))
                 (format track_info_fd "\n")
                 (set! cg::global_frame_pos (+ 1 cg::global_frame_pos))))
           ))
     t)
   (reverse (utt.relation.items utt cg_relation))
   )
  t)
)

(define (clustergen::load_hmmstates_utt u params)
"(clustergen::load_hmmstates_utt utterances params)
Load in the labels from from a different label dir.  This assumes 
HMM state sized labels, but it doesn't really care."
   (utt.relation.create u "HMMstate")
   (utt.relation.create u "segstate")
   (utt.relation.load u "HMMstate"
                      (format nil "lab/%s.sl" 
                              (utt.feat u "fileid")))
   ;; Link HMMstate labels to Segment labels
   (set! seg (utt.relation.first u 'Segment))
   (set! state (utt.relation.first u 'HMMstate))
   (while seg
          (item.set_feat seg "fileid" fileid)
          (set! segstate (utt.relation.append u 'segstate seg))
          (set! segname (item.name seg))
          (set! seg_end (item.feat seg "end"))

          (while (and state (<= (item.feat state "end") seg_end))
;             (if (and (string-equal segname "pau")
;                      (< (item.feat state "duration") 0.100))
;                 (begin
;                   ;; skip this short silence 
;                   (set! ostate state)
;                   (set! state (item.next state))
;                   (item.delete ostate))
                 (begin
                   (item.append_daughter segstate state)
                   ;; upto space because the label reading code forces this
                   (item.set_name 
                    state (format nil "%s_%s" segname 
                                  (string-before (item.name state) " ")
                                  ))
                   (set! state (item.next state)))
;                 )
             )
          (set! seg (item.next seg))
          (if seg (set! seg_end (item.feat seg "end")))
          )

   ;; Dispose of trailing end states (probably pauses)
   (while state
     (set! next_state (item.next state))
     (item.delete state)
     (set! state next_state))

   t)

(define (cg::close_enough a b delta)
  "(cg::close_enough a b)
Because the floats get moved a little when written and read as ascii, we
have this little function that returns t if these are within delta 
of each other."
  (let ((diff (- a b)))
    (if (< diff 0)
        (set! diff (* -1 diff)))
    (if (< diff delta)
        t
        nil)))

(define (clustergen::load_ccoefs_utt utt params)
  "(load_ccoefs utt params) 
Load Combined Coefficients into this utt and link it in"
  (let ( (ccoefs (track.load 
                  (format 
                   nil 
                   (get_param 'cg_ccoefs_template params "ccoefs/%s.mcep")
                   (utt.feat utt "fileid"))))
         (clunit_name_feat (get_param 'clunit_name_feat params "name"))
         (x 0))
    
    (utt.relation.create utt 'mcep)
    (utt.relation.create utt 'mcep_link)
    (utt.set_feat utt "param_track" ccoefs)
    (set! param_track_num_frames (track.num_frames ccoefs))
    (utt.set_feat utt "param_track_num_frames"
                  param_track_num_frames)

    (set! states (utt.relation.items utt 'HMMstate))
    (set! mcep_pos 0)
    (set! x 0)

    (while states
      (set! end (item.feat (car states) "end"))
      (set! mcep_parent (utt.relation.append utt 'mcep_link (car states)))
      (while (and 
              (or (< mcep_pos end) ;; floating point precision problem
                  (cg::close_enough mcep_pos end 0.002)
                  )
              (< x param_track_num_frames))
             (set! mcep_item (utt.relation.append utt 'mcep))
             (item.append_daughter mcep_parent mcep_item)
             (item.set_feat mcep_item "frame_number" x)
             (item.set_feat mcep_item "name" (item.name mcep_parent))
             (item.set_feat mcep_item "time" (track.get_time ccoefs x))
             (set! mcep_pos (track.get_time ccoefs x))
             (set! x (+ 1 x)))
      (set! states (cdr states)))
    ;; Because build utts only goes up to one silence after last 
    ;; non-silence we can have a mismatch between the length of the predicted
    ;; number of frames and the actual frames -- this crashes the cg_test
    ;; stuff.
;    (format t "%s %f %f %d %d\n" 
;            (utt.feat utt "fileid")
;            end mcep_pos x (track.num_frames ccoefs))
    utt))

(define (clustergen::extract_unittype_mcep_files datafile unittypes)
  ;; For each unittype extract their type specific vectors and 
  ;; feats and put them in a unittype specific file.  This additional
  ;; step is required in the utt-by-utt processing model
  (mapcar
   (lambda (unittype)
     (format t "extracting MCEP %d vectors and feature lists for %s\n" 
             (+ 1 (cadr unittype)) (car unittype))
     (system 
      ;; Get track info
      (format 
       nil 
       "$FESTVOXDIR/src/clustergen/cg_get_track %s %s festival/disttabs/%s.mcep\n"
       datafile
       (car unittype)
       (car unittype)))
     ;; Get feats info
     (system 
      (format 
       nil 
       "$FESTVOXDIR/src/clustergen/cg_get_feats %s %s festival/feats/%s.feats\n"
       datafile
       (car unittype)
       (car unittype)))
     )
   unittypes)
  t)

(define (clustergen::extract_unittype_all_files datafile unittypes)
  ;; For each unittype extract their type specific vectors and 
  ;; feats and put them in a unittype specific file.  This additional
  ;; step is required in the utt-by-utt processing model

  (system
   (format 
    nil 
    "$CLUSTERGENDIR/cg_get_feats_all %s\n"
    datafile))
  t)

(define (clustergen::extract_unittype_all_files_traj datafile unittypes)
  ;; For each unittype extract their type specific vectors and 
  ;; feats and put them in a unittype specific file.  This additional
  ;; step is required in the utt-by-utt processing model

  (system
   (format nil 
    "$CLUSTERGENDIR/cg_get_feats_all %s traj\n"
    datafile))

  (system
   (format nil 
    "$CLUSTERGENDIR/cg_get_feats_all_traj %s\n"
    datafile))

  t)

(define (clustergen::extract_unittype_f0_files datafile unittypes)
  ;; For each unittype extract their type specific vectors and 
  ;; feats and put them in a unittype specific file.  This additional
  ;; step is required in the utt-by-utt processing model
  (mapcar
   (lambda (unittype)
     (format t "extracting %d F0 feature lists for %s\n" 
             (+ 1 (cadr unittype)) (car unittype))
     (system 
      (format 
       nil 
       "$CLUSTERGENDIR/cg_get_f0_feats %s %s festival/feats/%s_f0.feats\n"
       datafile
       (car unittype)
       (car unittype)))
     )
   unittypes)
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  Clustering functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (clustergen::do_clustering unittypes cg_params build_tree type)
  "(clustergen::do_clustering unittypes cg_params)
Cluster different unit types."
  (if cg:parallel_tree_build
      (set! system parallelSystemStore)) ; Don't run system directly during tree building
  (mapcar
   (lambda (unittype)
     (format t "Clustergen %s tree build on: %s\n" type (car unittype))
     (build_tree (car unittype) cg_params)
     t)
   unittypes)
  (if cg:parallel_tree_build
      (begin
	(parallelSystemFlush) ; Build trees in parallel
	(set! system actualSystem))) ; Restore the system command
  t)

(defvar wagon-balance-size 0)

(if (probe_file "festvox/unittype_stop_values.scm")
    (set! unittype_stop_values (load "festvox/unittype_stop_values.scm" t)))

(define (cg_find_stop_value unittype cg_params)
  (if (boundp 'unittype_stop_values)
      (begin
        (let ((svp (assoc_string unittype unittype_stop_values)))
          (if svp
              (cadr svp)
              (get_param 'wagon_cluster_size_mcep cg_params 100)))
        )
      (begin
        (get_param 'wagon_cluster_size_mcep cg_params 100))))

(define (clustergen_build_mcep_tree unittype cg_params)
"Build tree with Wagon for this unittype."
;(format t "\n\nHSM\n\n")
  (defvar cg::cluster_feats "-track_start 1")
  (set! stopvalue (cg_find_stop_value unittype cg_params))
  (let ((command 
	 (format nil "%s %s %s -vertex_output mean -desc %s -data '%s' -test '%s' -balance %s -track '%s' -stop %s -output '%s' %s"
                 (if cg:rfs
                     "./bin/wagon_rf"
                     (get_param 'wagon_progname cg_params "$ESTDIR/bin/wagon"))
;                 "-stepwise -swopt rmse"
                 ""  ;; seems to be better with recent tests 12/01/06
                 cg::cluster_feats   ;; default -track_start 1
                 (get_param 'wagon_field_desc cg_params "wagon")
                 (format nil "festival/feats/%s.feats" ;; .train
                         unittype)
                 (format nil "festival/feats/%s.feats" ;; .test
                         unittype)
		 (get_param 'wagon_balance_size cg_params 0)
                 (format nil "festival/disttabs/%s.mcep" unittype)
                 stopvalue
                 (format nil "festival/trees/%s_mcep.tree" unittype)
		 (get_param 'wagon_other_params cg_params "")
		 )))
;;    Needed if you want to do stepwise
;     (system (format nil
;                     "./bin/traintest %s\n"
; 		 (string-append 
; 		  (get_param 'db_dir cg_params "./")
; 		  (get_param 'feats_dir cg_params "festival/feats/")
; 		  unittype
; 		  (get_param 'feats_ext cg_params ".feats"))))
        (format t "%s\n" command)
        (system command)))

(define (clustergen_build_str_tree unittype cg_params)
"Build tree with Wagon for this unittype."
  (defvar cg::cluster_feats "-track_start 1")
  (let ((command 
	 (format nil "%s %s %s -vertex_output mean -desc %s -data '%s' -test '%s' -balance %s -track '%s' -stop %s -output '%s' %s"
		 (get_param 'wagon_progname cg_params "$ESTDIR/bin/wagon")
;                 "-stepwise -swopt rmse"
                 ""  ;; seems to be better with recent tests 12/01/06
                 cg::cluster_feats   ;; default -track_start 1
;                 (get_param 'wagon_field_desc cg_params "wagon")
                 "festival/clunits/str.desc"
                 (format nil "festival/feats/%s.feats" ;; .train
                         unittype)
                 (format nil "festival/feats/%s.feats" ;; .test
                         unittype)
		 (get_param 'wagon_balance_size cg_params 0)
                 (format nil "festival/disttabs/%s.mcep" unittype)
		 (get_param 'wagon_cluster_size_mcep cg_params 100)
                 (format nil "festival/trees/%s_mcep.tree" unittype)
		 (get_param 'wagon_other_params cg_params "")
		 )))
;;    Needed if you want to do stepwise
;     (system (format nil
;                     "./bin/traintest %s\n"
; 		 (string-append 
; 		  (get_param 'db_dir cg_params "./")
; 		  (get_param 'feats_dir cg_params "festival/feats/")
; 		  unittype
; 		  (get_param 'feats_ext cg_params ".feats"))))
        (format t "%s\n" command)
        (system command)))

(define (clustergen_build_mcep_trajectory_tree unittype cg_params)
"Build tree with Wagon for this unittype."
  (let ((command 
	 (format nil "%s %s -track_start 0 -desc %s -data '%s' -test '%s' -balance %s -track '%s' -unittrack '%s' -stop %s -output '%s' %s"
		 (get_param 'wagon_progname cg_params "wagon")
;                 "-stepwise -swopt rmse"
                 ""  ;; seems to be better with recent tests 12/01/06
                 (get_param 'wagon_field_desc cg_params "wagon")
                 (format nil "festival/feats/%s.feats" ;; .train
                         unittype)
                 (format nil "festival/feats/%s.feats" ;; .test
                         unittype)
		 (get_param 'wagon_balance_size cg_params 0)
                 (format nil "festival/disttabs/%s.mcep" unittype)
                 (format nil "festival/disttabs/%s.idx" unittype)
		 (get_param 'wagon_cluster_size_mcep cg_params 100)
                 (format nil "festival/trees/%s_mcep.tree" unittype)
		 (get_param 'wagon_other_params cg_params "")
		 )))
;;    Needed if you want to do stepwise
;     (system (format nil
;                     "./bin/traintest %s\n"
; 		 (string-append 
; 		  (get_param 'db_dir cg_params "./")
; 		  (get_param 'feats_dir cg_params "festival/feats/")
; 		  unittype
; 		  (get_param 'feats_ext cg_params ".feats"))))
    (format t "%s\n" command)
    (system command)))

(define (clustergen_build_f0_tree unittype cg_params)
"Build tree with Wagon for this unittype."
  (let ((command 
	 (format nil "%s %s -desc %s -data '%s' -test '%s' -balance %s -stop %s -output '%s' %s"
		 (get_param 'wagon_progname cg_params "wagon")
;                 "-stepwise -swopt rmse"
                 "-ignore '(R:mcep_link.parent.lisp_duration)'"
                 (format nil "festival/clunits/f0.desc")
                 (format nil "festival/feats/%s_f0.feats" ;; .train
                         unittype)
                 (format nil "festival/feats/%s_f0.feats" ;; .test
                         unittype)
		 (get_param 'wagon_balance_size cg_params 0)
		 (get_param 'wagon_cluster_size_f0 cg_params 200)
                 (format nil "festival/trees/%s_f0.tree" unittype)
		 (get_param 'wagon_other_params cg_params "")
		 )))
;;    Needed if you want to do stepwise
;     (system (format nil
;                     "./bin/traintest %s\n"
; 		 (string-append 
; 		  (get_param 'db_dir cg_params "./")
; 		  (get_param 'feats_dir cg_params "festival/feats/")
; 		  unittype
; 		  (get_param 'feats_ext cg_params ".feats"))))
    (format t "%s\n" command)
    (system command)))

(define (clustergen:collect_trees unittypes params type)
"Collect the trees into one file as an assoc list, and dump leafs into
a track file"
  (let ((fd (fopen 
             (format nil "festival/trees/%s_%s.tree"
	      (get_param 'index_name params "all.") type)
	      "wb")))
    (format fd ";; Autogenerated list of clustergen %s trees\n" type)
    (mapcar
     (lambda (unit)
       (set! tree (car (load (string-append "festival/trees/"
                                            (car unit) 
                                            "_" type
                                            ".tree") t)))
       (pprintf (list (car unit) tree) fd))
     unittypes)
    (format fd "\n")
    (fclose fd)
    ))

(define (clustergen:collect_mcep_trees unittypes params type)
"Collect the trees into one file as an assoc list, and dump leafs into
a track file"
  (let ((fd (fopen 
             (format nil "festival/trees/%s_%s.tree"
	      (get_param 'index_name params "all.") type)
	      "wb"))
        (rawtrackfd
         (fopen 
             (format nil "festival/trees/%s_%s.rawparams"
	      (get_param 'index_name params "all.") type)
	      "wb")))
    (format fd ";; Autogenerated list of clustergen mcep trees\n")
    (set! vector_num 0)
    (format fd "(cg_name_feat %s)\n"
            (get_param 'clunit_name_feat params "name"))           
    (mapcar
     (lambda (unit)
       (set! tree (car (load (string-append "festival/trees/"
                                            (car unit) 
                                            "_mcep" 
                                            ".tree") t)))
       (set! tree (clustergen::dump_tree_vectors tree rawtrackfd))
       (pprintf (list (car unit) tree) fd)
       (set! tree nil)
       t
       )
     unittypes)
    (format fd "\n")
    (fclose fd)
    (fclose rawtrackfd)
    ;; Convert rawtrack to a headered track
    (system
     (format 
      nil
      "$ESTDIR/bin/ch_track -itype ascii -otype est_binary -s 0.005 -o %s %s"
      (format nil "festival/trees/%s_%s.params"
	      (get_param 'index_name params "all.") type)
      (format nil "festival/trees/%s_%s.rawparams"
	      (get_param 'index_name params "all.") type)))

    (format t "%d unittypes as %d subunittypes dumped\n"
            (length unittypes) vector_num)
    ))

(define (rpf_dump_tree intreefile outfiletree outfileparams)
  (let ((oft (fopen outfiletree "w"))
        (ofp (fopen outfileparams "w"))
        (tree (car (load intreefile t))))
    (set! vector_num 0)
    (pprintf (clustergen::dump_tree_vectors tree ofp) oft)
    (fclose oft)
    (fclose ofp)
    t
    )
)

(define (rpf_map_trees infiletrees outfiletrees infileparammap)
  (let ((oft (fopen outfiletrees "w"))
        (pmap (load infileparammap t))
        (trees (load infiletrees t)))
    (format oft "%l\n" (car trees)) ;; the cg_name_feat
    (mapcar
     (lambda (treeplus)
       (pprintf (list (car treeplus)
                      (rpf_map_tree (cadr treeplus) pmap)) oft)
       t
       )
     (cdr trees))
    (fclose oft)
    t
    )
)

(define (rpf_map_tree tree pmap)
  "(define (rpf_map_tree tree pmap)
Map the param number at the leave of the tree to the new value in pmap"
(cond
 ((cdr tree)  ;; a question
  (list
   (car tree)
   (rpf_map_tree (car (cdr tree)) pmap)
   (rpf_map_tree (car (cdr (cdr tree))) pmap)))
 (t           ;; tree leaf 
  (set-car! (car tree) (cadr (assoc (caar tree) pmap)))
  tree))
)

(define (clustergen::dump_tree_vectors tree rawtrackfd)
"(clustergen::dump_tree_vectors tree rawtrackfd)
Dump the means and stds at each leaf into an ascii file 
replacing the leaf node with an index"
(cond
 ((cdr tree)  ;; a question
  (list
   (car tree)
   (clustergen::dump_tree_vectors (car (cdr tree)) rawtrackfd)
   (clustergen::dump_tree_vectors (car (cdr (cdr tree))) rawtrackfd)))
 (t           ;; tree leaf
  (mapcar
   (lambda (x) 
     ;; dump the mean and the std
     (format rawtrackfd "%f %f " 
             (if (or (string-equal "nan" (car x) )
                     (string-equal "-nan" (car x) ))
                 0.0
                 (car x))
             (if (or (string-equal "nan" (cadr x) )
                     (string-equal "-nan" (cadr x) ))
                 0.0
                 (cadr x))))
   (caar tree))
  (format rawtrackfd "\n")
  (set-car! (car tree) vector_num) ;; replace list of mean/stddev with index #
  (set! vector_num (+ 1 vector_num))
  tree)))

(define (clustergen:collect_mcep_trajectory_trees unittypes params)
"Collect the trees into one file as an assoc list, and dump leafs into
a track file"
  (let ((fd (fopen 
             (format nil "festival/trees/%s_%s.tree"
	      (get_param 'index_name params "all.") "mcep")
	      "wb"))
        (rawtrackfd
         (fopen 
             (format nil "festival/trees/%s_%s.rawparams"
	      (get_param 'index_name params "all.") "mcep")
	      "wb")))
    (format fd ";; Autogenerated list of clustergen mcep trees\n")
    (set! vector_num 0)
    (format fd "(cg::trajectory t)\n")
    (if cg::trajectory_ola
        (format fd "(cg::trajectory_ola t)\n"))
    (mapcar
     (lambda (unit)
       (set! tree (car (load (string-append "festival/trees/"
                                            (car unit) 
                                            "_mcep" 
                                            ".tree") t)))
       (set! tree (clustergen::dump_tree_trajectories tree rawtrackfd))
       (pprintf (list (car unit) tree) fd))
     unittypes)
    (format fd "\n")
    (fclose fd)
    (fclose rawtrackfd)
    ;; need to convert rawtrack to a headered track
    (system
     (format 
      nil
      "$ESTDIR/bin/ch_track -itype ascii -otype est_binary -s 0.005 -o %s %s"
      (format nil "festival/trees/%s_%s.params"
	      (get_param 'index_name params "all.") "mcep")
      (format nil "festival/trees/%s_%s.rawparams"
	      (get_param 'index_name params "all.") "mcep")))

    (format t "%d unittypes as %d subunittypes dumped\n"
            (length unittypes) vector_num)
    ))

(define (clustergen::dump_tree_trajectories tree rawtrackfd)
"(clustergen::dump_tree_vectors tree rawtrackfd)
Dump the means and stds at each leaf into an ascii file 
replacing the leaf node with an index"
(cond
 ((cdr tree)  ;; a question
  (list
   (car tree)
   (clustergen::dump_tree_trajectories (car (cdr tree)) rawtrackfd)
   (clustergen::dump_tree_trajectories (car (cdr (cdr tree))) rawtrackfd)))
 (t           ;; tree leaf
  (set! trajectory_length (length (caar tree)))
  (mapcar
   (lambda (v)
     (mapcar
      (lambda (x) 
        ;; dump the mean and the std
        (format rawtrackfd "%f %f " 
                (if (string-equal "nan" (car x) ) 0.0 (car x))
               (if (string-equal "nan" (cadr x) ) 0.0 (cadr x))))
      v)
     (format rawtrackfd "\n"))
   (caar tree)) ;; AWB DEBUG change this for psynch options
  (set-car! (car tree) ;; replace list of mean/stddev with index # + length
            (list vector_num trajectory_length))
  (set! vector_num (+ vector_num trajectory_length))
  tree)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  Old functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (clustergen_build_tree_cv unittype cg_params)
"Build tree with Wagon for this unittype with cross-validation."
  (let ((command 
	 (format nil "$CLUSTERGENDIR/wagon_cv %s -desc %s -balance 0 -track '%s' -stop %s -output '%s' %s"
		 (string-append 
		  (get_param 'db_dir cg_params "./")
		  (get_param 'feats_dir cg_params "festival/feats/")
		  unittype
		  (get_param 'feats_ext cg_params ".feats"))
		 (if (probe_file
		      (string-append
		       (get_param 'db_dir cg_params "./")
		       (get_param 'wagon_field_desc cg_params "wagon")
		       "." unittype))
		     ;; So there can be unittype specific desc files
		     (string-append
		       (get_param 'db_dir cg_params "./")
		       (get_param 'wagon_field_desc cg_params "wagon")
		       "." unittype)
		     (string-append
		       (get_param 'db_dir cg_params "./")
		       (get_param 'wagon_field_desc cg_params "wagon")))
		 (string-append 
		  (get_param 'db_dir cg_params "./")
		  (get_param 'vector_dir cg_params "festival/disttabs/")
		  unittype
		  (get_param 'vector_ext cg_params ".mcep"))
		 (get_param 'wagon_cluster_size cg_params 20)
		 (string-append 
		  (get_param 'db_dir cg_params "./")
		  (get_param 'trees_dir cg_params "festival/trees/")
		  unittype
		  (get_param 'trees_ext cg_params ".tree"))
		 (get_param 'wagon_other_params cg_params "")
		 )))
    (format t "%s\n" command)
    (system command)))
(defvar cg_build_tree clustergen_build_tree_cv)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  adaptation/conversion functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (cg_wave_nothing utt) utt)

(define (build_cga_source_files promptfile)

  (set! cluster_synth_method cg_wave_nothing)
  (mapcar
   (lambda (x)
     (format t "cga build source files for %s\n" (car x))
     (set! utt (SynthText (cadr x)))
     (set! param_track (utt.feat utt "param_track"))
     (utt.save utt 
      (format nil "cga/source/utt/%s.utt" (car x)))
     (track.save param_track
      (format nil "cga/source/ccoefs/%s.mcep" (car x)))
     ;; Dump out 5ms labels
     (set! fd (fopen (format nil "cga/source/lab/%s.lab" (car x)) "w"))
     (format fd "#\n")
     (set! frame 0)
     (while (< frame (track.num_frames param_track))
        (format fd "%f 125 %f\n" 
                (track.get_time param_track frame)
                (track.get_time param_track frame)
                )
        (set! frame (+ 1 frame)))
     (fclose fd)
     )
   (load promptfile t))
  t
)

(define (cga_link_coefs utt fileid)
  (let (map_track m mframes p pframes)
    (set! map_track 
          (track.load (format nil "cga/target/ccoefs/%s.mcep" fileid)))
    (utt.set_feat utt "map_track" map_track)
    (set! param_track (utt.feat utt "param_track"))

    (utt.relation.create utt "param_map")
    (utt.relation.create utt "param_map_link")
    (utt.relation.create utt "param_align")
    (utt.relation.load utt "param_align"
        (format nil "cga/target/lab/%s.lab" fileid))
  
    (set! m 0)
    (set! mframes (track.num_frames map_track))
    (set! p 0)
    (set! pframes (track.num_frames param_track))
    (set! mseg (utt.relation.first utt "param_align"))
    (set! pseg (utt.relation.first utt "mcep"))
    
    (while (and mseg (< m mframes))
       ;; Find param_track vector we will map to
       (while (and pseg mseg 
                   (<=
                   (track.get_time param_track (item.feat pseg "frame_number"))
                   (parse-number (item.name mseg))))
          (set! pseg (item.next pseg)))
       (set! end (item.feat mseg "end"))
       (set! mcep_parent (utt.relation.append utt "param_map_link" pseg))
       (set! n m)
       ;; for each mapped frame add to param_map, and link to mcep
       (while (and pseg
                   (< (track.get_time map_track m) end)
                   (< m mframes))
          (set! nseg (utt.relation.append utt "param_map" nil))
          (item.append_daughter mcep_parent nseg)
          (item.set_feat nseg "frame_number" m)
          (item.set_feat nseg "name"
                         (item.feat nseg "R:param_map_link.parent.name")
                         )
          (set! m (+ 1 m))
          )
       (set! mseg (item.next mseg))
    )
  )
)

(define (clustergen_cga::dump_vectors_and_feats_utt utt params)
  (let ((cg_relation (get_param 'clunit_relation params "Segment"))
        (cg_mcep (utt.feat utt "map_track"))
        (feats (car (cdr (assoc 'feats params))))
        (cname "ignore"))
    ;; note name_units and dump_vectors_and_feats must traverse
    ;; the units in the same order
    (set! cg_mcep_channels (track.num_channels cg_mcep))
  (mapcar 
   (lambda (s)
     (set! cname (item.feat s "clunit_name"))
     (if (or (string-equal cname "0")
             (string-equal cname "ignore"))
         t ;; do nothing
         (begin
           ;; Vector values
           (format track_info_fd "%s " cname)
           (set! f 0)
           (set! frame_number (item.feat s "frame_number"))
           (while (< f cg_mcep_channels)
              (format track_info_fd "%f "
                      (track.get cg_mcep frame_number f))
              (set! f (+ 1 f)))
           ;; deltas
;           (set! f 0)
;           (while (< f cg_mcep_channels)
;              (format track_info_fd "%f "
;                       (- (track.get cg_mcep frame_number f)
;                          (track.get cg_mcep last_frame_number f)
;;                          )
;                       )
;              (set! f (+ 1 f)))
;           (set! last_frame_number frame_number)
           (format track_info_fd "\n")
           ;; Feature values
           (format feat_info_fd "%s " cname)
           (mapcar 
            (lambda (f)
              (set! fval (unwind-protect 
                          (item.feat s f) 
                          "0"))
              (if (string-matches fval " *")
                  (format feat_info_fd "%l " fval)
                  (format feat_info_fd "%s " fval)))
            feats)
           (format feat_info_fd "\n")
           ))
     t)
   (reverse (utt.relation.items utt cg_relation))
   )
  t)
)

(define (build_cga_model promptfile)

  (set! cluster_synth_method cg_wave_nothing)
  (set! cga:clustergen_params
        (append
         (list
          '(clunit_relation param_map)
          '(wagon_cluster_size_cga 50)
          '(clunit_name_feat "name")
          )
         clustergen_params))

  (set! cg::unittypes nil)
  (set! cg::durstats nil)
  (set! cg::unitid 0)

  (mapcar
   (lambda (x)
     (format t "%s Processing\n" (car x))
     (set! track_info_fd 
           (fopen (format nil "festival/coeffs/%s.mcep" (car x)) "w"))
     (set! feat_info_fd 
           (fopen (format nil "festival/coeffs/%s.feats" (car x)) "w"))
     (unwind-protect
      (begin
        ;; load source utts
        (set! utt (SynthText (cadr x)))
        ;; load target coeffs and align them
        (cga_link_coefs utt (car x))
        ;; dump features -- like clustergen
        (clustergen::name_units utt cga:clustergen_params)
        (clustergen_cga::dump_vectors_and_feats_utt utt cga:clustergen_params)
      ))
     (fclose track_info_fd)
     (fclose feat_info_fd)
     )
   (load promptfile t))

   (format t "Extracting features by unittype\n")
   (clustergen::extract_unittype_all_files promptfile cg::unittypes)

   (cga:get_prosody_stats)

   (clustergen::do_clustering
    cg::unittypes cga:clustergen_params
    clustergen_build_cga_tree "cga")
   (clustergen:collect_cga_trees cg::unittypes cga:clustergen_params)

  t)

(define (cga:get_prosody_stats)
  (let ((source_f0 (load "etc/f0.params" t))
        (target_f0 (load "cga/target/etc/f0.params" t)))
    (set! cga:source_f0_mean
          (parse-number (string-after (car source_f0) "=")))
    (set! cga:source_f0_stddev
          (parse-number (string-after (cadr source_f0) "=")))
    (set! cga:target_f0_mean
          (parse-number (string-after (car target_f0) "=")))
    (set! cga:target_f0_stddev
          (parse-number (string-after (cadr target_f0) "=")))
    ))

(define (clustergen:collect_cga_trees unittypes params)
"Collect the trees into one file as an assoc list, and dump leafs into
a track file"
  (let ((fd (fopen 
             (format nil "festival/trees/%s_%s.tree" 
                     (get_param 'index_name params "all.") "cga")
             "wb"))
        (rawtrackfd
         (fopen 
             (format nil "festival/trees/%s_%s.rawparams"
                     (get_param 'index_name params "all.") "cga")
	      "wb")))
    (format fd ";; Autogenerated list of clustergen cga trees\n")
    (set! vector_num 0)
    (format fd "(cga::source_f0_mean %f)\n" cga:source_f0_mean)
    (format fd "(cga::source_f0_stddev %f)\n" cga:source_f0_stddev)
    (format fd "(cga::target_f0_mean %f)\n" cga:target_f0_mean)
    (format fd "(cga::target_f0_stddev %f)\n" cga:target_f0_stddev)
    (mapcar
     (lambda (unit)
       (set! tree (car (load (string-append "festival/trees/"
                                            (car unit) 
                                            "_cga" 
                                            ".tree") t)))
       (set! tree (clustergen::dump_tree_vectors tree rawtrackfd))
       (pprintf (list (car unit) tree) fd))
     unittypes)
    (format fd "\n")
    (fclose fd)
    (fclose rawtrackfd)
    ;; need to convert rawtrack to a headered track
    (system
     (format 
      nil
      "$ESTDIR/bin/ch_track -itype ascii -otype est_binary -s 0.005 -o %s %s"
      (format nil "festival/trees/%s_%s.params"
	      (get_param 'index_name params "all.") "cga")
      (format nil "festival/trees/%s_%s.rawparams"
	      (get_param 'index_name params "all.") "cga")))

    (format t "%d unittypes as %d vectors dumped\n"
            (length unittypes) vector_num)
    ))

(define (clustergen_build_cga_tree unittype cg_params)
"Build tree with Wagon for this unittype."
  (let ((command 
	 (format nil "%s %s -track_start 1 -desc %s -data '%s' -test '%s' -balance %s -track '%s' -stop %s -output '%s' %s"
		 (get_param 'wagon_progname cg_params "wagon")
;                 "-stepwise -swopt rmse"
                 ""  ;; seems to be better with recent tests 12/01/06
                 (get_param 'wagon_field_desc cg_params "wagon")
                 (format nil "festival/feats/%s.feats" ;; .train
                         unittype)
                 (format nil "festival/feats/%s.feats" ;; .test
                         unittype)
		 (get_param 'wagon_balance_size cg_params 0)
                 (format nil "festival/disttabs/%s.mcep" unittype)
		 (get_param 'wagon_cluster_size_cga cg_params 100)
                 (format nil "festival/trees/%s_cga.tree" unittype)
		 (get_param 'wagon_other_params cg_params "")
		 )))
;;    Needed if you want to do stepwise
;     (system (format nil
;                     "./bin/traintest %s\n"
; 		 (string-append 
; 		  (get_param 'db_dir cg_params "./")
; 		  (get_param 'feats_dir cg_params "festival/feats/")
; 		  unittype
; 		  (get_param 'feats_ext cg_params ".feats"))))
    (format t "%s\n" command)
    (system command)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  Adapt (2009)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (ClusterGen_adapt filename testdir)
  ;; Tests from natural durations

  (set! old_cg_predict_unvoiced cg_predict_unvoiced)
  (set! cg_predict_unvoiced nil)
  (set! cg:mlpg nil)
  ;; I keep the param_tracks in a global list otherwise gc causes a crash
  ;; this is a work around solution, but far from correct
  (set! xxx nil)
  (mapcar
   (lambda (x)
     (format t "CG adapt_mcep %s\n" (car x))
     (gc)
     (set! real_track
           (track.load
            (format
             nil
             (get_param 'cg_ccoefs_template clustergen_params
"ccoefs/%s.mcep")
             (car x))))
     (set! utt1 (utt.load nil (format nil "festival/utts/%s.utt" (car
x))))
     (clustergen::load_hmmstates_utt utt1 clustergen_params)
     (clustergen::load_ccoefs_utt utt1 clustergen_params)

     ;(set! maps (load "festvox/dag_deen_ingmarcg_deenmap.scm"))

    ; (mapcar
     ; (lambda (x)
        ;(format t "%s " (item.feat x "name"))
   ;    (item.set_feat x "name" (lookup deenmap (item.feat x "name"))))
        ;(format t "%s\n" (item.feat x "name")))
;       (utt.relation.items utt1 'Segment))

     (if (assoc 'cg::trajectory clustergen_mcep_trees)
        (ClusterGen_predict_trajectory utt1) ;; predict trajectory
        (ClusterGen_predict_mcep utt1) ;; predict vector types
;        (ClusterGen_acoustic_predict_mcep utt1 real_track)
        )
    (set! i 0)
    (set! nf 0)
    ;(format t "%d\n" nf)
     (mapcar
      (lambda (frame)
        (set! nf (+ 1 nf)))
      (utt.relation.items utt1 "mcep"))

    (format t "%d\n" nf)
    (set! cluster_track
          (track.resize nil
           nf 1))
     (mapcar
      (lambda (frame)
        (track.set_time cluster_track i (item.feat frame "frame_number"))
        (track.set cluster_track i 0 (item.feat frame "clustergen_param_frame"))
        (set! i (+ 1 i)))
      (utt.relation.items utt1 "mcep"))
     (track.save cluster_track (format nil "adapt/%s.tgt" (car x)))
     ;;; keep these in core as weird things happen if they are gc'd
     (set! xxx (cons (utt.feat utt1 "param_track") xxx))
     t)
   (load filename t))
  (set! cg_predict_unvoiced old_cg_predict_unvoiced)
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  Mixed excitation tuning function
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (me_mlsa_track trackfile wavefile)
  (let ((t1 (track.load trackfile))
        (t1 nil) (w1 nil)
        (nf 0) (f 0) (c 0) (str_params nil))
    (if (not (boundp 'me_mix_filters))
        (set! me_mix_filters
              (load "etc/mix_excitation_filters.txt" t)))
    (set! nf (track.num_frames t1))
    (set! str_params (track.resize nil nf 5))
    (set! f 0)
    (while (< f nf)
       (track.set_time str_params f (track.get_time t1 f))
       (set! c 0)
       (while (< c 5)
          (track.set str_params f c 
                     (track.get t1 f (+ c 51)))
          (set! c (+ 1 c)))
       (set! f (+ 1 f)))
    (set! nc (+ 1 25))
    (set! t2 (track.resize nil nf nc))
    (set! f 0)
    (while (< f nf)
       (track.set_time t2 f (track.get_time t1 f)) 
       (set! c 0)
       (while (< c nc)
          (track.set t2 f c (track.get t1 f c))
          (set! c (+ 1 c)))
       (set! f (+ 1 f)))

    (set! w1 (me_mlsa t2 str_params))
    (wave.save w1 wavefile)
    )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  Testing function
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (ClusterGen_test_set filename testdir)
  (set! old_cg_predict_unvoiced cg_predict_unvoiced)
  (set! cg_predict_unvoiced nil)
  (mapcar 
   (lambda (x)
     (format t "CG test %s\n" (car x))
     (set! utt1 (SynthText (cadr x)))
     (utt.save.wave utt1 (format nil "%s/%s.wav" testdir (car x)))
     (track.save
      (utt.feat utt1 "param_track")
      (format nil "%s/%s.mcep" testdir (car x)))
     t)
   (load filename t))
  (set! cg_predict_unvoiced old_cg_predict_unvoiced)
  t)

(define (ClusterGen_test_resynth filename testdir)
  ;; Tests from natural durations

  (set! old_cg_predict_unvoiced cg_predict_unvoiced)
  (set! cg_predict_unvoiced nil)
  (mapcar 
   (lambda (x)
     (format t "CG test_resynth %s\n" (car x))
     (unwind-protect
      (cg_do_test_resynth x testdir)
      (format t "CG test_resynth %s Failed\n" (car x)))
     t)
   (load filename t))
  (set! cg_predict_unvoiced old_cg_predict_unvoiced)
  t)

(define (cg_do_test_resynth x testdir)

  (if cg:vuv_predict_dump
      (begin
        (set! cg_predict_unvoiced t) ;; needed for dumping and testing
        (set! cg:vuv_predict_dump 
              (fopen (format nil "vuv/%s.vuvfeats" (car x)) "w"))))
  (set! fileid (car x))
  (gc)
  (set! real_track 
        (track.load (format nil
          (get_param 'cg_ccoefs_template clustergen_params "ccoefs/%s.mcep")
          (car x))))
  (set! utt1 (utt.load nil (format nil "festival/utts/%s.utt" (car x))))
  (clustergen::load_hmmstates_utt utt1 clustergen_params)
  (clustergen::load_ccoefs_utt utt1 clustergen_params)
  (if (assoc 'cg::trajectory clustergen_mcep_trees)
      (ClusterGen_predict_trajectory utt1) ;; predict trajectory
      (cond
       ((consp cg:multimodel) ;; predict vector with multimodels
        (ClusterGen_predict_params_mm utt1)
        )
       (t
        (ClusterGen_predict_mcep utt1))))

  (set! xxx (cons (utt.feat utt1 "param_track") xxx)) ;; to stop gc bug
  (track.save (utt.feat utt1 "param_track") 
              (format nil "%s/%s.mcep" testdir (car x)))
  (if (and cg::generate_resynth_waves (boundp 'mlsa_resynthesis)) ;; hnm
      (begin
        (set! cg_predict_unvoiced t)
        (if (assoc 'cg::trajectory clustergen_mcep_trees)
            (ClusterGen_predict_trajectory utt1) ;; predict trajectory
            (cond
             ((consp cg:multimodel) ;; predict vector with multimodels
              (ClusterGen_predict_params_mm utt1))
             (t
              (ClusterGen_predict_mcep utt1))) )
        (set! real_track 
              (track.load
               (format nil
                (get_param 'cg_ccoefs_template clustergen_params "ccoefs/%s.mcep")
                (car x))))
        (set! predicted_track (utt.feat utt1 "param_track"))
        (set! xxx (cons (list real_track predicted_track) xxx))
        (set! i 0)
        (mapcar       ;; copy f0
         (lambda (m)
           (if (> (track.get predicted_track i 0) 0)
               (track.set predicted_track i 0 (track.get real_track i 0)))
           (set! i (+ 1 i)))
         (utt.relation.items utt1 'mcep))
        (set! cg_predict_unvoiced nil)
        (cg_wave_synth utt1)
        (wave.save (utt.wave utt1)
         (format nil "%s/%s.wav" testdir (car x)))
        )) ;; end of resynth wave
  (if cg:vuv_predict_dump
      (fclose cg:vuv_predict_dump))
)

(define (ClusterGen_hsm_resynth filename testdir)
  ;; Tests from natural durations

  (set! old_cg_predict_unvoiced cg_predict_unvoiced)
  (set! cg_predict_unvoiced nil)
  (mapcar 
   (lambda (x)
     (format t "CG hsm_resynth %s\n" (car x))
     (gc)
     (set! real_track 
           (track.load 
            (format 
             nil
             (get_param 'cg_ccoefs_template clustergen_params "ccoefs/%s.mcep")
             (car x))))
     (set! utt1 (utt.load nil (format nil "festival/utts/%s.utt" (car x))))
     (clustergen::load_hmmstates_utt utt1 clustergen_params)
     (clustergen::load_ccoefs_utt utt1 clustergen_params)
     (if (assoc 'cg::trajectory clustergen_mcep_trees)
        (ClusterGen_predict_trajectory utt1) ;; predict trajectory
        (ClusterGen_predict_mcep_hsm utt1) ;; predict vector types
        )

     (cg_wave_synth_hsm utt1)
     
     (track.save (utt.feat utt1 "param_track") 
                 (format nil "%s/%s.mcep" testdir (car x)))
     (wave.save
      (utt.wave utt1)
      (format nil "%s/%s.wav" testdir (car x)))
     t)
   (load filename t))
  (set! cg_predict_unvoiced old_cg_predict_unvoiced)
  t)

(define (ClusterGen_acoustic_predict_mcep utt real_track)
  ;; Acoustically look for best mcep
  (let ((param_track nil)
        (frame_advance cg:frame_shift)
        (frame nil) (f nil) (f0_val)
        (num_channels (/ (track.num_channels clustergen_param_vectors) 2))
        )

    ;; Predict mcep values
    (set! i 0)
    (set! param_track
          (track.resize nil
           (utt.feat utt "param_track_num_frames")
           num_channels))
    (utt.set_feat utt "param_track" param_track)
    (mapcar
     (lambda (mcep)
       ;; Predict mcep frame
       (let ((mcep_tree (assoc_string (item.name mcep) clustergen_mcep_trees))
             (f0_tree (assoc_string (item.name mcep) clustergen_f0_trees)))
         (if (null mcep_tree)
             (format t "ClusterGen: can't find cluster tree for %s\n"
                     (item.name mcep))
             (begin
               ;; F0 prediction
               (set! f0_val (wagon mcep (cadr f0_tree)))
               (ClusterGen_predict_F0 mcep (cadr f0_val) param_track)

               ;; MCEP prediction
;               (format t "checking %s\n" (item.name mcep))
               (set! frame (find_closest_vector 
                            (cadr mcep_tree)
                            (list -1 10000000)
                            i real_track))
;               (format t "   bestest %l\n" frame)
               (set! j 1)
               (set! f (car frame))
               (while (< j num_channels)
                  (track.set param_track i j 
                    (track.get clustergen_param_vectors f (* 2 j)))
                  (set! j (+ 1 j)))))
         
         (track.set_time param_track i (* i frame_advance))
         (set! i (+ 1 i))))
     (utt.relation.items utt 'mcep))
    (cg_F0_smooth param_track 0)
    (mapcar
     (lambda (x)
       (cg_mcep_smooth param_track x))
     '( 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25))
    utt
  )
)

(define (find_closest_vector tree bests i track)
  ;; returns (best_index best_distance)
  (cond
   ((cdr tree) ;; a question
    (find_closest_vector
     (car (cdr tree))
     (find_closest_vector
      (car (cdr (cdr tree)))
      bests
      i track)
     i track))
   ((< (set! new_best
             (find_vector_distance 
              (caar tree) clustergen_param_vectors i track
              0 1 (cadr bests)))
       (cadr bests))
;    (format t "   better at %l\n" new_best)
    (list (caar tree) new_best))
   (t
    bests)))

(define (find_vector_distance a tracka b trackb sumx c best_val)
  (cond
   ((> sumx best_val)
    best_val) ;; not better 
   ((> c 24) 
    sumx)     ;; end, is better
   (t
    (set! d (- (track.get tracka a (* 2 c))
               (track.get trackb b c)))
    (find_vector_distance
     a tracka b trackb
     (+ (* d d) sumx)
     (+ 1 c)
     best_val))))

(if (not (boundp 'fabs))
    (define (fabs x) (if (< x 0) (* -1 x) x)))

;;;
;;;  Go through given utterances and score them wrt to how well they
;;;  can be predicted.  
;;;
(define (ClusterGen_score_frames filename scoredir)
  (set! old_cg_predict_unvoiced cg_predict_unvoiced)
  (set! cg_predict_unvoiced nil)
  (mapcar 
   (lambda (x)
     (format t "CG scoring %s\n" (car x))
     (gc)
     (set! real_track 
           (track.load 
            (format 
             nil
             (get_param 'cg_ccoefs_template clustergen_params "ccoefs/%s.mcep")
             (car x))))
     (set! utt1 (utt.load nil (format nil "festival/utts/%s.utt" (car x))))
     (clustergen::load_hmmstates_utt utt1 clustergen_params)
     (clustergen::load_ccoefs_utt utt1 clustergen_params)
     (if (assoc 'cg::trajectory clustergen_mcep_trees)
        (ClusterGen_predict_trajectory utt1) ;; predict trajectory
        (ClusterGen_predict_mcep utt1) ;; predict vector types
        )
     (set! score_track (track.copy real_track))
     (set! param_track (utt.feat utt1 "param_track"))
     (set! f 0)
     (mapcar
      (lambda (mcep)
        (set! j 0)
        (set! cpv (item.feat mcep "clustergen_param_frame"))
        (while (< j (track.num_channels real_track))
           (set! q (- (track.get real_track f j)
                      (track.get clustergen_param_vectors cpv (* 2 j))))
           (set! q (* q q))
           (if (not (equal? 0 q))
               (track.set 
                score_track 
                f j
                (/ (sqrt q)
                   (track.get clustergen_param_vectors cpv (+ 1 (* 2 j)))) ;; stddev
                ))
           (set! j (+ 1 j)))
        (set! f (+ 1 f)))
      (utt.relation.items utt1 'mcep))
     (track.save 
      score_track
      (format nil "%s/%s.mcep" scoredir (car x)))
     t)
   (load filename t))
  (set! cg_predict_unvoiced old_cg_predict_unvoiced)
  t)

;;;;;;;;;;;;;;;;;;;;;;;;

(define (make_simple_sl ttd)
  "(make_simple_sl ttd)
When there are no state labels, make some with one third splits"

  (set! phones nil)
  (mapcar
   (lambda (x)
     (set! utt1 (utt.load nil (format nil "festival/utts/%s.utt" (car x))))
     (set! ofd (fopen (format nil "lab/%s.sl" (car x)) "w"))
     (format ofd "#\n")
     (mapcar
      (lambda (l)
        (set! n (item.name l))
        (if (null (member_string n phones))
            (set! phones (cons n phones)))
        (set! s (item.feat l "p.end"))
        (set! e (item.feat l "end"))
        (set! third (/ (- e s) 3.0))
        (format ofd "%1.3f 125 1 %s\n" (+ s third) (item.name l))
        (format ofd "%1.3f 125 2 %s\n" (+ s third third) (item.name l))
        (format ofd "%1.3f 125 3 %s\n" e (item.name l)))
      (utt.relation.items utt1 'Segment))
     (fclose ofd))
   (load ttd t))
  (setq ofd (fopen "etc/statenames" "w"))
  (mapcar
   (lambda (p)
     (format ofd "%s %s_1 %s_2 %s_3\n" p p p p))
   phones)
  t
)

(provide 'clustergen_build)
