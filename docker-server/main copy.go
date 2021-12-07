package main

import (
    "log"
    "net/http"
    "html/template"
    "os"
)

type Page struct {
  Title string
  Body []byte
}

func (p *Page) save() error {
  filename :=p.Title + ".txt"
  return os.WriteFile(filename, p.Body, 0600)
}

func loadPage(title string) (*Page, error) {
  filename := title + ".txt"
  body, err := os.ReadFile(filename)
  if err != nil {
    return nil, err
  }
  return &Page{Title: title, Body: body}, nil
}

func renderTemplate(w http.ResponseWriter, tmpl string, p *Page) {
  t, _ := template.ParseFiles("static/" + tmpl + ".html")
  t.Execute(w, p)
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
  title := r.URL.Path[len("/index"):]
  p, _ := loadPage(title)
  renderTemplate(w, "index", p)
}

func editHandler(w http.ResponseWriter, r *http.Request) {
  title := r.URL.Path[len("/edit"):]
  p, err := loadPage(title)
  if err != nil {
    p = &Page{Title: title}
  }
  renderTemplate(w, "edit", p)
}

func main() {
  http.HandleFunc("/index/", indexHandler)
  http.HandleFunc("/edit/", editHandler)
  log.Fatal(http.ListenAndServe(":8080", nil))
}
