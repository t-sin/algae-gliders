(in-package #:cl-user)
(defpackage #:bhshooter/shooter
  (:use #:cl #:sdl2)
  (:shadowing-import-from #:bhshooter/const
                          #:*shooter-offset-x*
                          #:*shooter-offset-y*
                          #:*shooter-width*
                          #:*shooter-height*
                          #:*game-images*
                          #:texture-texture
                          #:texture-width
                          #:texture-height)
  (:export #:shooter-init
           #:shooter-proc))
(in-package #:bhshooter/shooter)

;;;
;;; actors

(defstruct actor
  tag available? start-tick px py
  pos-fn draw-fn act-fn)

(defun init-actors ()
  (let ((array (make-array 5000)))
    (loop
      :for n :from 0 :below (length array)
      :do (setf (aref array n) (make-actor)))
    array))


;; disable-on-out
(defun disable-on-out (a pos tick)
  (declare (ignore tick))
  (let ((x (car pos))
        (y (cdr pos)))
    (when (or (> -15 (- x *shooter-offset-x*)) (< *shooter-width* (- x *shooter-offset-x*))
              (> -15 (- y *shooter-offset-y*)) (< *shooter-height* (- y *shooter-offset-y*)))
      (setf (actor-available? a) nil))))

;;;
;;; vm

(defstruct vm
  actors tick equeue)

(defun alloc-actor (vm)
  (let ((idx (position-if #'(lambda (a) (null (actor-available? a)))
                          (vm-actors vm))))
    (when idx
      (aref (vm-actors vm) idx))))

(defun vm-shot-to (vm sx sy v tx ty)
  (let ((a (alloc-actor vm)))
    (when a
      (setf (actor-available? a) t
            (actor-px a) sx
            (actor-py a) sy
            (actor-pos-fn a) (let* ((d (sqrt (+ (expt (- tx sx) 2)
                                                (expt (- ty sy) 2))))
                                    (dx (* v (/ (- tx sx) d)))
                                    (dy (* v (/ (- ty sy) d))))
                               #'(lambda (x y tick)
                                   (declare (ignore tick))
                                   (cons (+ x dx) (+ y dy))))))))

(defun vm-shot (vm sx sy move-fn)
  (let ((a (alloc-actor vm)))
    (setf (actor-available? a) t
          (actor-px a) sx
          (actor-py a) sy
          (actor-pos-fn a) move-fn)))

(defun execute (vm)
  (loop
    :for queue := (vm-equeue vm)
    :for e := (car queue)
    :while (and queue (= (car e) (vm-tick vm)))
    :do (progn
          (let ((op (cdr e)))
            (ecase (car op)
              (:shot (apply #'vm-shot vm (cdr op)))
              (:shot-to (apply #'vm-shot-to vm (cdr op)))
              (:interrupt)))
          (setf (vm-equeue vm) (cdr queue)))))

;;;
;;; shooter

(defparameter *event-queue*
  '((100 . (:shot-to 500 500 0.5 300 300))
    (100 . (:shot-to 500 500 0.7 300 300))
    (100 . (:shot-to 500 500 0.9 300 300))))

(defun draw-bullet (renderer pos dir tick)
  (declare (ignore tick))
  (let* ((img (getf *game-images* :bullet))
         (w (texture-width img))
         (h (texture-height img))
         (tex (bhshooter/const:texture-texture img)))
    (set-texture-blend-mode tex :add)
    (render-copy renderer tex
                 :dest-rect (make-rect (floor (- (car pos) (/ w 2)))
                                       (floor (-(cdr pos) (/ h 2)))
                                       w h))))

(defparameter *vm* nil)

(defun shooter-init ()
  (setf *vm* (make-vm :tick 0
                      :actors (init-actors)
                      :equeue *event-queue*)))

(defun shooter-proc (renderer)
  (let ((tick (vm-tick *vm*)))
    (execute *vm*)
    (loop
      :for a :across (vm-actors *vm*)
      :when (and a (actor-available? a))
      :do (let ((pos (funcall (actor-pos-fn a)
                              (actor-px a) (actor-py a) tick)))
            (setf (actor-px a) (car pos)
                  (actor-py a) (cdr pos))
            (when pos
              (funcall #'draw-bullet renderer pos 0 tick)
;;              (funcall (actor-act-fn a) a pos tick)
              ))))
  (incf (vm-tick *vm*)))
