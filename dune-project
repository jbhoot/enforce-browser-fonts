(lang dune 3.8)

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
 ; (depends (melange (>= 1.0.0)) (ocaml-lsp-server :with-dev-setup) (utop :with-dev-setup) (ocamlformat :with-dev-setup)))
 (depends
  (melange
   (>= 1.0.0))
  ocaml-lsp-server
  utop
  ocamlformat))

(maintainers "Jayesh Bhoot")

(authors "Jayesh Bhoot")
