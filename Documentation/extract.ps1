$word = New-Object -ComObject Word.Application
$word.Visible = $false

$doc1 = $word.Documents.Open("c:\Users\Lenovo\Eden\Documentation\Autonomous Software Engineer PoC Document.docx")
$doc1.Content.Text | Out-File -Encoding utf8 "c:\Users\Lenovo\Eden\Documentation\poc_text.txt"
$doc1.Close()

$doc2 = $word.Documents.Open("c:\Users\Lenovo\Eden\Documentation\PRD Generation for Autonomous Engineer.docx")
$doc2.Content.Text | Out-File -Encoding utf8 "c:\Users\Lenovo\Eden\Documentation\prd_text.txt"
$doc2.Close()

$word.Quit()
Write-Host "Done extracting text from documents"
