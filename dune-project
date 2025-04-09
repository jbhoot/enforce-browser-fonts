(lang dune 3.16)

(using melange 0.1)

(using directory-targets 0.1)

(generate_opam_files true)

(package
 (name enforce-browser-fonts)
 (synopsis "Enforce browser fonts easily on websites instead of letting them use their own fonts")
 (description
  "Enforce browser fonts easily on websites instead of letting them use their own fonts")
 (homepage "https://github.com/jyshb/enforce-browser-fonts")
 (bug_reports "https://github.com/jyshb/enforce-browser-fonts/issues")
 (allow_empty)
 (depends
  (ocaml
   (= 5.3.0))
  ;; 5.1.0-53 => melange v5.1.0 linked to ocaml v5.3.x
  (melange
   (= 5.1.0-53))
  reason ; reason-promise in package.json needs it
  utop))

(maintainers "Jayesh Bhoot")

(authors "Jayesh Bhoot")
