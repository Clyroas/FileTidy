Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Design tokens. One accent, everything else is graphite.
function To-Color($hex){ $h=$hex.TrimStart('#'); return [Drawing.Color]::FromArgb([Convert]::ToInt32($h.Substring(0,2),16),[Convert]::ToInt32($h.Substring(2,2),16),[Convert]::ToInt32($h.Substring(4,2),16)) }
function To-Pad($l,$t,$r,$b){ return New-Object System.Windows.Forms.Padding($l,$t,$r,$b) }
$ui=@{ Bg='#0E1015'; Surface='#161A22'; Raised='#1F2532'; Line='#2B3342'; Text='#E9ECF3'; Muted='#8B94A8'; Faint='#5C6578'; Accent='#F0A63C'; AccentInk='#1B1408'; Good='#57C08D'; Bad='#E5695A'; Ink='#120C0C'; RowAlt='#191E27'; Sel='#33405C'; OnRaised='#232B3A'; OnMuted='#79839A' }
foreach($k in @($ui.Keys)){ $ui[$k]=To-Color $ui[$k] }
$catColor=@{ Images='#6FA8FF'; Documents='#9C8CF0'; Installers='#E5695A'; Audio='#F0A63C'; Video='#E879C6'; Archives='#57C08D'; Other='#8B94A8'; Archive='#C3A46B' }
foreach($k in @($catColor.Keys)){ $catColor[$k]=To-Color $catColor[$k] }
$fontBody=New-Object Drawing.Font('Segoe UI',9)
$fontMicro=New-Object Drawing.Font('Segoe UI Semibold',8)
$fontMono=New-Object Drawing.Font('Consolas',8.5)

function Show-Error($message){ [void][Windows.Forms.MessageBox]::Show($message,'FileTidy',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error) }
function Show-Note($message,$title){ [void][Windows.Forms.MessageBox]::Show($message,$title,[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information) }
function Show-Confirm($message,$title){ return [Windows.Forms.MessageBox]::Show($message,$title,[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question) -eq 'Yes' }

# Long work (hashing thousands of files) must not freeze the window, but must not be re-entered either.
$script:busy=$false
function Enter-Busy(){ if($script:busy){return $false}; $script:busy=$true; $script:form.Cursor=[Windows.Forms.Cursors]::WaitCursor; $script:tabs.Enabled=$false; return $true }
function Exit-Busy(){ $script:busy=$false; $script:form.Cursor=[Windows.Forms.Cursors]::Default; $script:tabs.Enabled=$true }

function Set-Button($button,[bool]$on){
  $button.Enabled=$on
  switch($button.Tag){
    'primary' { $button.BackColor=$(if($on){$ui.Accent}else{$ui.Raised}); $button.ForeColor=$(if($on){$ui.AccentInk}else{$ui.OnMuted}); $button.FlatAppearance.BorderColor=$(if($on){$ui.Accent}else{$ui.Line}); $button.FlatAppearance.MouseOverBackColor=$(if($on){$ui.Accent}else{$ui.Raised}) }
    'danger'  { $button.BackColor=$(if($on){$ui.Bad}else{$ui.Raised}); $button.ForeColor=$(if($on){$ui.Ink}else{$ui.OnMuted}); $button.FlatAppearance.BorderColor=$(if($on){$ui.Bad}else{$ui.Line}); $button.FlatAppearance.MouseOverBackColor=$(if($on){$ui.Bad}else{$ui.Raised}) }
    default   { $button.BackColor=$(if($on){$ui.Raised}else{$ui.Surface}); $button.ForeColor=$(if($on){$ui.OnRaised}else{$ui.OnMuted}); $button.FlatAppearance.BorderColor=$ui.Line; $button.FlatAppearance.MouseOverBackColor=$ui.OnRaised }
  }
}
function New-Button($text,$kind,$width){ $b=New-Object System.Windows.Forms.Button; $b.Text=$text; $b.Tag=$kind; $b.Width=$width; $b.Height=31; $b.FlatStyle='Flat'; $b.Cursor=[Windows.Forms.Cursors]::Hand; $b.Margin=To-Pad(8,0,0,0); $b.Font=New-Object Drawing.Font('Segoe UI Semibold',9); $b.FlatAppearance.BorderSize=1; $b.FlatAppearance.MouseDownBackColor=$ui.Accent; Set-Button $b $false; return $b }
function New-TextBox($width){ $t=New-Object System.Windows.Forms.TextBox; $t.BackColor=$ui.Raised; $t.ForeColor=$ui.Text; $t.BorderStyle='FixedSingle'; $t.Width=$width; $t.Height=25; return $t }
function New-Rule(){ $r=New-Object System.Windows.Forms.Panel; $r.Dock='Top'; $r.Height=1; $r.BackColor=$ui.Line; return $r }
function New-Panel($height){ $p=New-Object System.Windows.Forms.Panel; $p.Dock='Top'; $p.Height=$height; $p.BackColor=$ui.Surface; return $p }
function New-Micro($text,$fore){ $l=New-Object System.Windows.Forms.Label; $l.Text=$text; $l.AutoSize=$true; $l.Font=$fontMicro; $l.ForeColor=$(if($fore){$fore}else{$ui.Faint}); $l.BackColor=$ui.Surface; return $l }

# Children are docked in reverse z-order, so a panel is filled top-down by adding its children bottom-up.
function New-PathRow($parent,$label,$initial,$browseAction){
  $p=New-Object System.Windows.Forms.Panel; $p.Dock='Top'; $p.Height=32; $p.BackColor=$ui.Surface
  $box=New-TextBox 300; $box.Dock='Fill'; $p.Controls.Add($box)
  $l=New-Object System.Windows.Forms.Label; $l.Text=$label; $l.Dock='Left'; $l.Width=140; $l.TextAlign='MiddleLeft'; $l.ForeColor=$ui.Muted; $p.Controls.Add($l)
  $b=New-Button 'Choose folder...' 'secondary' 118; $b.Dock='Right'; $b.Height=27; $b.Margin=To-Pad(0,0,0,0); $p.Controls.Add($b)
  $b.Add_Click(({ & $browseAction $box }).GetNewClosure())
  $parent.Controls.Add($p)
  return $box
}

function Get-UniquePath($path) { if(!(Test-Path -LiteralPath $path)){return $path}; $dir=[IO.Path]::GetDirectoryName($path); $stem=[IO.Path]::GetFileNameWithoutExtension($path); $ext=[IO.Path]::GetExtension($path); $n=1; do {$candidate=Join-Path $dir "$stem ($n)$ext"; $n++} while(Test-Path -LiteralPath $candidate); return $candidate }
function Style-Grid($g){
  $g.Dock='Fill'; $g.AutoGenerateColumns=$false; $g.AllowUserToAddRows=$false; $g.ReadOnly=$true; $g.MultiSelect=$true
  $g.BackgroundColor=$ui.Surface; $g.BorderStyle='None'; $g.GridColor=$ui.Line; $g.CellBorderStyle='SingleHorizontal'
  $g.EnableHeadersVisualStyles=$false; $g.ColumnHeadersHeightSizeMode='DisableResizing'; $g.ColumnHeadersHeight=28
  $g.AllowUserToResizeRows=$false; $g.AllowUserToOrderColumns=$false; $g.AllowUserToResizeRows=$false
  $h=$g.ColumnHeadersDefaultCellStyle; $h.BackColor=$ui.Surface; $h.ForeColor=$ui.Muted; $h.Font=$fontMicro; $h.SelectionBackColor=$ui.Surface; $h.SelectionForeColor=$ui.Muted; $h.Padding=To-Pad(8,0,8,0)
  $d=$g.DefaultCellStyle; $d.BackColor=$ui.Surface; $d.ForeColor=$ui.Text; $d.Font=$fontBody; $d.Padding=To-Pad(8,0,8,0); $d.SelectionBackColor=$ui.Sel; $d.SelectionForeColor=$ui.Text; $d.WrapMode='None'
  $g.RowTemplate.Height=27; $g.EnableAlternatingRowsDifferentColors=$true; $g.AlternatingRowsDefaultCellStyle.BackColor=$ui.RowAlt; $g.AlternatingRowsDefaultCellStyle.SelectionBackColor=$ui.Sel
  $g.StandardTab=$true
}
function New-GridArea($parent,[string[]]$names,$emptyText){
  $area=New-Object System.Windows.Forms.Panel; $area.Dock='Fill'; $area.BackColor=$ui.Surface; $area.Padding=To-Pad(16,4,16,16)
  $g=New-Object System.Windows.Forms.DataGridView; Style-Grid $g; $g.AutoSizeColumnsMode='Fill'; $g.RowHeadersVisible=$false; $g.SelectionMode='FullRowSelect'
  foreach($name in $names){ $c=New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c.HeaderText=$name; $c.SortMode='Automatic'; [void]$g.Columns.Add($c) }
  $e=New-Object System.Windows.Forms.Label; $e.Dock='Fill'; $e.BackColor=$ui.Surface; $e.ForeColor=$ui.Faint; $e.TextAlign='MiddleCenter'; $e.Font=$fontBody; $e.Text=$emptyText
  $area.Controls.Add($g); $area.Controls.Add($e); $area.Controls.SetChildIndex($e,0); $parent.Controls.Add($area)
  return [pscustomobject]@{ Grid=$g; Empty=$e; Area=$area }
}
function Set-Empty($empty,$grid,$text){ $empty.Text=$text; $empty.Visible=($grid.Rows.Count -eq 0) }

# A slim band between the options and the grid: what the list is, and how much of it there is.
function New-ListHead($parent,$text){ $bar=New-Panel 30; $label=New-Micro $text; $label.AutoSize=$false; $label.Dock='Fill'; $label.TextAlign='MiddleLeft'; $bar.Controls.Add($label); $count=New-Object System.Windows.Forms.Label; $count.Dock='Right'; $count.Width=180; $count.TextAlign='MiddleRight'; $count.Font=$fontMono; $count.ForeColor=$ui.Faint; $count.BackColor=$ui.Surface; $bar.Controls.Add($count); $parent.Controls.Add($bar); return $count }
function New-ActionBar($parent){ $bar=New-Panel 60; $status=New-Object System.Windows.Forms.Label; $status.Dock='Fill'; $status.TextAlign='MiddleLeft'; $status.ForeColor=$ui.Muted; $status.BackColor=$ui.Surface; $status.AutoEllipsis=$true; $bar.Controls.Add($status)
  $flow=New-Object System.Windows.Forms.FlowLayoutPanel; $flow.Dock='Right'; $flow.Width=300; $flow.FlowDirection='RightToLeft'; $flow.WrapContents=$false; $flow.BackColor=$ui.Surface; $bar.Controls.Add($flow); $parent.Controls.Add($bar)
  return [pscustomobject]@{ Panel=$bar; Status=$status; Flow=$flow } }

# Cleaner
$form=New-Object System.Windows.Forms.Form; $form.Text='FileTidy'; $form.Size='980,700'; $form.MinimumSize='760,520'; $form.StartPosition='CenterScreen'; $form.BackColor=$ui.Bg; $form.ForeColor=$ui.Text; $form.Font=$fontBody
$script:form=$form
$accentBar=New-Object System.Windows.Forms.Panel; $accentBar.Dock='Top'; $accentBar.Height=3; $accentBar.BackColor=$ui.Accent; $form.Controls.Add($accentBar)
$header=New-Object System.Windows.Forms.Panel; $header.Dock='Top'; $header.Height=84; $header.BackColor=$ui.Surface; $form.Controls.Add($header)
$head=New-Object System.Windows.Forms.TableLayoutPanel; $head.Dock='Fill'; $head.BackColor=$ui.Surface; $head.ColumnCount=2; $head.RowCount=1; $head.Padding=To-Pad(24,0,24,0)
[void]$head.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,100))); [void]$head.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute,260))); [void]$head.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
$titleBlock=New-Object System.Windows.Forms.Panel; $titleBlock.Dock='Fill'; $titleBlock.BackColor=$ui.Surface
$title=New-Object System.Windows.Forms.Label; $title.Text='FileTidy'; $title.Font=New-Object Drawing.Font('Segoe UI Semibold',20); $title.ForeColor=$ui.Text; $title.BackColor=$ui.Surface; $title.Location='0,18'; $title.AutoSize=$true; $titleBlock.Controls.Add($title)
$sub=New-Object System.Windows.Forms.Label; $sub.Text='Preview first. Nothing moves until you confirm.'; $sub.Font=$fontBody; $sub.ForeColor=$ui.Muted; $sub.BackColor=$ui.Surface; $sub.Location='2,54'; $sub.AutoSize=$true; $titleBlock.Controls.Add($sub)
[void]$head.Controls.Add($titleBlock,0,0)
$headNote=New-Object System.Windows.Forms.Label; $headNote.Text='Everything stays on this PC.'; $headNote.Dock='Fill'; $headNote.TextAlign='MiddleRight'; $headNote.Font=$fontMono; $headNote.ForeColor=$ui.Faint; $headNote.BackColor=$ui.Surface; [void]$head.Controls.Add($headNote,1,0)
$header.Controls.Add($head)

$tabs=New-Object System.Windows.Forms.TabControl; $tabs.Dock='Fill'; $tabs.BackColor=$ui.Bg; $tabs.Padding=New-Object System.Windows.Forms.Point(18,6); $tabs.DrawMode='OwnerDraw'; $tabs.ItemSize=New-Object System.Drawing.Size(198,34); $tabs.SizeMode='Normal'; $form.Controls.Add($tabs)
$script:tabs=$tabs
$tabBrushSurface=New-Object Drawing.SolidBrush($ui.Bg); $tabBrushActive=New-Object Drawing.SolidBrush($ui.Text); $tabBrushIdle=New-Object Drawing.SolidBrush($ui.Muted); $tabBrushAccent=New-Object Drawing.SolidBrush($ui.Accent); $tabBrushTrack=New-Object Drawing.SolidBrush($ui.Raised)
$fontTabIdle=New-Object Drawing.Font('Segoe UI',9); $fontTabActive=New-Object Drawing.Font('Segoe UI Semibold',9)
$tabs.Add_DrawItem({
  param($sender,$e)
  $gr=$e.Graphics; $b=$e.Bounds; $gr.FillRectangle($tabBrushSurface,$b)
  $active=($sender.SelectedIndex -eq $e.Index); $label=$sender.TabPages[$e.Index].Text
  if($active){ $gr.FillRectangle($tabBrushTrack,$b); $gr.FillRectangle($tabBrushAccent,(New-Object Drawing.Rectangle($b.X,$b.Y+$b.Height-3,$b.Width,3))) }
  $font=$(if($active){$fontTabActive}else{$fontTabIdle}); $brush=$(if($active){$tabBrushActive}else{$tabBrushIdle})
  $size=$gr.MeasureString($label,$font); $gr.DrawString($label,$font,$brush,(New-Object Drawing.PointF(($b.X+20),(($b.Height-$size.Height)/2)+1)))
})

$cleanTab=New-Object System.Windows.Forms.TabPage('Downloads Cleaner'); $cleanTab.BackColor=$ui.Surface; $cleanTab.Padding=To-Pad(0,0,0,0); $tabs.TabPages.Add($cleanTab)
$clean=New-GridArea $cleanTab @('FILE','DESTINATION') ("Nothing to show yet." + "`r`n" + "Choose a folder and run Preview changes. Destinations are colour-coded by category.")
$cleanHead=New-ListHead $cleanTab 'PREVIEW'
$cleanBar=New-ActionBar $cleanTab; $cleanStatus=$cleanBar.Status
$cleanTop=New-Panel 92; $cleanTop.Padding=To-Pad(16,14,16,12); $cleanTab.Controls.Add($cleanTop)
$cleanRule=New-Rule; $cleanTop.Controls.Add($cleanRule)
$cleanOpts=New-Object System.Windows.Forms.FlowLayoutPanel; $cleanOpts.Dock='Top'; $cleanOpts.Height=30; $cleanOpts.FlowDirection='LeftToRight'; $cleanOpts.WrapContents=$false; $cleanOpts.BackColor=$ui.Surface
$archiveCheck=New-Object System.Windows.Forms.CheckBox; $archiveCheck.Text='Move files older than'; $archiveCheck.AutoSize=$true; $archiveCheck.ForeColor=$ui.Text; $archiveCheck.BackColor=$ui.Surface; $archiveCheck.Margin=To-Pad(0,0,10,0)
$daysBox=New-Object System.Windows.Forms.NumericUpDown; $daysBox.Value=30; $daysBox.Minimum=1; $daysBox.Maximum=9999; $daysBox.Width=64; $daysBox.Height=25; $daysBox.Enabled=$false; $daysBox.Margin=To-Pad(0,0,10,0); $daysBox.BackColor=$ui.Raised; $daysBox.ForeColor=$ui.Text
$oldLabel=New-Object System.Windows.Forms.Label; $oldLabel.Text='days into an Archive folder'; $oldLabel.AutoSize=$true; $oldLabel.ForeColor=$ui.Muted; $oldLabel.BackColor=$ui.Surface; $oldLabel.Margin=To-Pad(0,5,0,0)
$cleanOpts.Controls.AddRange(@($archiveCheck,$daysBox,$oldLabel)); $cleanTop.Controls.Add($cleanOpts)
$archiveCheck.Add_CheckedChanged({$daysBox.Enabled=$archiveCheck.Checked})
$downloads=[Environment]::GetFolderPath('UserProfile')+'\Downloads'; $cleanFolder=New-PathRow $cleanTop 'Folder to organize' $downloads ${function:Choose-Folder}
$cleanPreview=New-Button 'Preview changes' 'secondary' 128; $cleanApply=New-Button 'Organize files' 'primary' 116; $cleanBar.Flow.Controls.Add($cleanApply); $cleanBar.Flow.Controls.Add($cleanPreview)
$cleanPlan=@()
$cleanGrid=$clean.Grid; $cleanEmpty=$clean.Empty
$cleanGrid.Add_CellFormatting({
  param($sender,$e)
  if($e.RowIndex -lt 0){ return }
  $cat=[string]$sender.Rows[$e.RowIndex].Tag
  if($cat){ $e.CellStyle.ForeColor=$catColor[$cat] }
})
$cleanPreview.Add_Click({
  if(!(Enter-Busy)){return}
  try { $root=(Resolve-Path -LiteralPath $cleanFolder.Text -ErrorAction Stop).Path; $script:cleanPlan=@(); $cleanGrid.Rows.Clear(); $exts=@{Images='.jpg','.jpeg','.png','.gif','.bmp','.webp','.svg','.heic','.tiff'; Documents='.pdf','.doc','.docx','.xls','.xlsx','.ppt','.pptx','.txt','.csv','.rtf','.odt'; Installers='.exe','.msi','.msix','.appx','.bat','.cmd'; Audio='.mp3','.wav','.flac','.m4a','.aac','.ogg','.wma'; Video='.mp4','.mkv','.avi','.mov','.wmv','.webm'; Archives='.zip','.rar','.7z','.tar','.gz','.bz2','.iso'}; $cutoff=(Get-Date).AddDays(-[int]$daysBox.Value)
    Get-ChildItem -LiteralPath $root -File | ForEach-Object { $cat='Other'; foreach($key in $exts.Keys){if($exts[$key] -contains $_.Extension.ToLower()){$cat=$key;break}}; if($archiveCheck.Checked -and $_.LastWriteTime -lt $cutoff){$cat='Archive'}; $target=Get-UniquePath (Join-Path (Join-Path $root $cat) $_.Name); $script:cleanPlan += [pscustomobject]@{Source=$_.FullName;Target=$target}; $i=$cleanGrid.Rows.Add($_.Name,($target.Substring($root.Length).TrimStart('\'))); $cleanGrid.Rows[$i].Tag=$cat }
    Set-Button $cleanApply ($cleanPlan.Count -gt 0); $cleanHead.Text=('{0} file(s)' -f $cleanPlan.Count); $cleanStatus.Text=$(if($cleanPlan.Count){'Ready to move. Check the list, then choose Organize files.'}else{'No files to organize in the top level of this folder.'})
  } catch { Show-Error $_.Exception.Message }
  finally { Set-Empty $cleanEmpty $cleanGrid ("Nothing to organize." + "`r`n" + "This tool only looks at files sitting directly in the folder you choose."); Exit-Busy }
})
$cleanApply.Add_Click({ if(!(Enter-Busy)){return}; if(!($script:cleanPlan.Count)){Exit-Busy;return}; if(!(Show-Confirm ("Move $($cleanPlan.Count) file(s) shown in the preview?") 'Organize files')){Exit-Busy;return}
  $n=0; try { foreach($item in $cleanPlan){ if(Test-Path -LiteralPath $item.Source){ New-Item -ItemType Directory -Force -Path (Split-Path $item.Target) | Out-Null; Move-Item -LiteralPath $item.Source -Destination $item.Target; $n++ } }; Show-Note "Organized $n file(s)." 'FileTidy' }
  catch { Show-Error "Moved $n file(s).`n$($_.Exception.Message)" }
  finally { Exit-Busy; $cleanPreview.PerformClick() } })

# Renamer
$renameTab=New-Object System.Windows.Forms.TabPage('Bulk Renamer'); $renameTab.BackColor=$ui.Surface; $renameTab.Padding=To-Pad(0,0,0,0); $tabs.TabPages.Add($renameTab)
$rename=New-GridArea $renameTab @('CURRENT NAME','NEW NAME') ("Nothing to show yet." + "`r`n" + "Choose a folder and run Preview rename. Only files sitting directly in the folder are renamed.")
$renameHead=New-ListHead $renameTab 'PREVIEW'
$renameBar=New-ActionBar $renameTab; $renameStatus=$renameBar.Status
$renameTop=New-Panel 124; $renameTop.Padding=To-Pad(16,14,16,12); $renameTab.Controls.Add($renameTop)
$renameRule=New-Rule; $renameTop.Controls.Add($renameRule)
$renameChecks=New-Object System.Windows.Forms.FlowLayoutPanel; $renameChecks.Dock='Top'; $renameChecks.Height=30; $renameChecks.FlowDirection='LeftToRight'; $renameChecks.WrapContents=$false; $renameChecks.BackColor=$ui.Surface
$spacesCheck=New-Object System.Windows.Forms.CheckBox; $spacesCheck.Text='Replace spaces with dashes'; $spacesCheck.Checked=$true; $spacesCheck.AutoSize=$true; $spacesCheck.ForeColor=$ui.Text; $spacesCheck.BackColor=$ui.Surface; $spacesCheck.Margin=To-Pad(0,0,20,0)
$numberCheck=New-Object System.Windows.Forms.CheckBox; $numberCheck.Text='Number files sequentially'; $numberCheck.AutoSize=$true; $numberCheck.ForeColor=$ui.Text; $numberCheck.BackColor=$ui.Surface
$renameChecks.Controls.AddRange(@($spacesCheck,$numberCheck)); $renameTop.Controls.Add($renameChecks)
$renameFields=New-Object System.Windows.Forms.TableLayoutPanel; $renameFields.Dock='Top'; $renameFields.Height=32; $renameFields.ColumnCount=6; $renameFields.RowCount=1; $renameFields.BackColor=$ui.Surface; $renameFields.Margin=To-Pad(0,0,0,0)
$renameCols=@( @(84,'Fixed'), @(60,'Fill'), @(72,'Fixed'), @(70,'Fill'), @(100,'Fixed'), @(70,'Fill') )
foreach($s in $renameCols){ [void]$renameFields.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle($(if($s[1] -eq 'Fill'){[System.Windows.Forms.SizeType]::Percent}else{[System.Windows.Forms.SizeType]::Absolute}),$s[0]))) }
[void]$renameFields.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent,100)))
function Add-RenameField($column,$text){ $l=New-Object Windows.Forms.Label; $l.Text=$text; $l.Dock='Fill'; $l.TextAlign='MiddleLeft'; $l.ForeColor=$ui.Muted; $l.BackColor=$ui.Surface; [void]$renameFields.Controls.Add($l,$column,0); $b=New-TextBox 100; $b.Dock='Fill'; [void]$renameFields.Controls.Add($b,($column+1),0); return $b }
$prefixBox=Add-RenameField 0 'Add prefix'; $findBox=Add-RenameField 2 'Find text'; $replaceBox=Add-RenameField 4 'Replace with'
$renameTop.Controls.Add($renameFields)
$renameFolder=New-PathRow $renameTop 'Folder' '' ${function:Choose-Folder}
$renamePreview=New-Button 'Preview rename' 'secondary' 128; $renameApply=New-Button 'Rename files' 'primary' 116; $renameBar.Flow.Controls.Add($renameApply); $renameBar.Flow.Controls.Add($renamePreview)
$renamePlan=@()
$renameGrid=$rename.Grid; $renameEmpty=$rename.Empty
$renameGrid.Add_CellFormatting({ param($sender,$e) if($e.ColumnIndex -eq 1){ $e.CellStyle.ForeColor=$ui.Accent } })
$renamePreview.Add_Click({
  if(!(Enter-Busy)){return}
  try {
    $root=(Resolve-Path -LiteralPath $renameFolder.Text -ErrorAction Stop).Path; $files=@(Get-ChildItem -LiteralPath $root -File | Sort-Object Name); $script:renamePlan=@(); $renameGrid.Rows.Clear(); $names=@{}; $i=0
    foreach($file in $files){ $i++; $stem=$file.BaseName; if($spacesCheck.Checked){$stem=$stem -replace '\s+','-'}; if($findBox.Text){$stem=$stem.Replace($findBox.Text,$replaceBox.Text)}; $stem=$prefixBox.Text+$stem; if($numberCheck.Checked){$stem='{0:D3}-{1}' -f $i,$stem}; $new=$stem+$file.Extension
      if($names.ContainsKey($new.ToLower())){throw "These settings create the same name twice: $new"}; $names[$new.ToLower()]=$true; $target=Join-Path $root $new
      if($target -cne $file.FullName){ $script:renamePlan += [pscustomobject]@{Source=$file.FullName;Target=$target}; [void]$renameGrid.Rows.Add($file.Name,$new) }
    }
    Set-Button $renameApply ($renamePlan.Count -gt 0); $renameHead.Text=('{0} file(s)' -f $renamePlan.Count); $renameStatus.Text=$(if($renamePlan.Count){'Ready to rename. Old names stay in the folder until you confirm.'}else{'No names change with these settings.'})
  } catch { Show-Error $_.Exception.Message }
  finally { Set-Empty $renameEmpty $renameGrid ("Nothing to rename." + "`r`n" + "This tool only renames files sitting directly in the folder you choose."); Exit-Busy }
})
$renameApply.Add_Click({ if(!(Enter-Busy)){return}; if(!($script:renamePlan.Count)){Exit-Busy;return}; if(!(Show-Confirm ("Rename $($renamePlan.Count) file(s) shown in the preview?") 'Rename files')){Exit-Busy;return}
  try { $temp=@(); $i=0; foreach($item in $renamePlan){ $i++; $tmp=Join-Path (Split-Path $item.Source) ".__filetidy_$i"; Move-Item -LiteralPath $item.Source -Destination $tmp; $temp += [pscustomobject]@{Source=$tmp;Target=$item.Target} }
    foreach($item in $temp){ Move-Item -LiteralPath $item.Source -Destination $item.Target }
    Show-Note "Renamed $($renamePlan.Count) file(s)." 'FileTidy' }
  catch { Show-Error $_.Exception.Message }
  finally { Exit-Busy; $renamePreview.PerformClick() } })

# Duplicate finder
$dupeTab=New-Object System.Windows.Forms.TabPage('Duplicate Finder'); $dupeTab.BackColor=$ui.Surface; $dupeTab.Padding=To-Pad(0,0,0,0); $tabs.TabPages.Add($dupeTab)
$dupe=New-GridArea $dupeTab @('KEEP / DUPLICATE','SIZE','PATH') ("No scan yet." + "`r`n" + "Choose a folder and scan. This tool walks subfolders too, and compares files by MD5 content hash.")
$dupeGrid=$dupe.Grid; $dupeEmpty=$dupe.Empty; $dupeGrid.Columns['PATH'].Visible=$false
foreach($col in $dupeGrid.Columns){ $col.SortMode='NotSortable' }
$dupeGrid.Columns['KEEP / DUPLICATE'].FillWeight=70; $dupeGrid.Columns['SIZE'].FillWeight=30
function Get-RowKind($row){ if(([string]$row.Cells['KEEP / DUPLICATE'].Value) -like 'KEEP*'){ return 'KEEP' } return 'DUPLICATE' }
$dupeHead=New-ListHead $dupeTab 'SCAN RESULT'
$dupeBar=New-ActionBar $dupeTab; $dupeStatus=$dupeBar.Status
$dupeTop=New-Panel 78; $dupeTop.Padding=To-Pad(16,14,16,12); $dupeTab.Controls.Add($dupeTop)
$dupeRule=New-Rule; $dupeTop.Controls.Add($dupeRule)
$dupeNote=New-Object System.Windows.Forms.Label; $dupeNote.Text='The first result in each match group is marked KEEP and can never be removed.'; $dupeNote.Dock='Top'; $dupeNote.Height=18; $dupeNote.ForeColor=$ui.Faint; $dupeNote.Font=$fontMono; $dupeNote.TextAlign='MiddleLeft'; $dupeTop.Controls.Add($dupeNote)
$dupeFolder=New-PathRow $dupeTop 'Folder to scan' '' ${function:Choose-Folder}
$scan=New-Button 'Scan for duplicates' 'secondary' 156; $remove=New-Button 'Move selected to Recycle Bin' 'danger' 208; $dupeBar.Flow.Controls.Add($remove); $dupeBar.Flow.Controls.Add($scan)
$script:dupeGroups=@()
$dupeGrid.Add_CellFormatting({ param($sender,$e) if($e.RowIndex -lt 0){ return }; if($e.ColumnIndex -eq 0){ $e.CellStyle.ForeColor=$(if((Get-RowKind $sender.Rows[$e.RowIndex]) -eq 'KEEP'){$ui.Good}else{$ui.Bad}) } })
$scan.Add_Click({
  if(!(Enter-Busy)){return}
  try {
    $root=(Resolve-Path -LiteralPath $dupeFolder.Text -ErrorAction Stop).Path; $dupeGrid.Rows.Clear(); $script:dupeGroups=@(); $dupeStatus.Text='Scanning files'+[char]0x2026+' this may take a while for large folders.'; $dupeStatus.ForeColor=$ui.Accent; [void]$dupeGrid.Parent.Refresh(); $form.Refresh()
    $bySize=@{}; Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $size=$_.Length; if(!$bySize.ContainsKey($size)){$bySize[$size]=@()}; $bySize[$size]+=$_.FullName }
    $seen=0
    foreach($files in $bySize.Values){
      if($files.Count -lt 2){continue}
      $byHash=@{}; foreach($path in $files){ try{ $h=(Get-FileHash -LiteralPath $path -Algorithm MD5).Hash; if(!$byHash.ContainsKey($h)){$byHash[$h]=@()}; $byHash[$h]+=$path }catch{} }
      foreach($group in $byHash.Values){ if($group.Count -gt 1){ $script:dupeGroups += ,$group } }
      $seen+=$files.Count; if(($seen % 25) -eq 0){ [Windows.Forms.Application]::DoEvents() }
    }
    $copies=0; foreach($group in $dupeGroups){ for($i=0;$i -lt $group.Count;$i++){ $p=$group[$i]; $label=if($i -eq 0){'KEEP  '}else{$copies++;'DUPLICATE  '}; $size='{0:N2} MB' -f ((Get-Item -LiteralPath $p).Length/1MB); [void]$dupeGrid.Rows.Add($label+$p,$size,$p) } }
    Set-Button $remove ($copies -gt 0); $dupeHead.Text=('{0} row(s)' -f $dupeGrid.Rows.Count); $dupeStatus.ForeColor=$ui.Muted
    $dupeStatus.Text=$(if($copies){"$($dupeGroups.Count) group(s), $copies copy/copies can be removed. Select only the red DUPLICATE rows."}else{"No exact duplicates found. $($dupeGrid.Rows.Count) file(s) were compared."})
  } catch { $dupeStatus.ForeColor=$ui.Muted; Show-Error $_.Exception.Message }
  finally { Set-Empty $dupeEmpty $dupeGrid ("Nothing scanned yet." + "`r`n" + "Choose a folder and scan. This tool walks subfolders too, and compares files by MD5 content hash."); Exit-Busy }
})
$remove.Add_Click({
  if(!(Enter-Busy)){return}
  $chosen=@($dupeGrid.SelectedRows | ForEach-Object { if((Get-RowKind $_) -eq 'DUPLICATE'){ $_.Cells['PATH'].Value } } | Where-Object { $_ })
  if(!$chosen.Count){ Exit-Busy; Show-Note 'Select one or more rows marked DUPLICATE first. KEEP rows are never removable.' 'FileTidy'; return }
  if(!(Show-Confirm ("Move $($chosen.Count) selected file(s) to the Windows Recycle Bin?") 'Move to Recycle Bin')){ Exit-Busy; return }
  $failed=@(); foreach($p in $chosen){ try{ Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p,'OnlyErrorDialogs','SendToRecycleBin') }catch{ $failed+=$p } }
  if($failed.Count){ Show-Error "Could not move $($failed.Count) file(s)."}else{ Show-Note "Moved $($chosen.Count) file(s) to the Recycle Bin." 'FileTidy' }
  Exit-Busy; $scan.PerformClick()
})

foreach($tab in @($cleanTab,$renameTab,$dupeTab)){ $rule=New-Rule; $tab.Controls.Add($rule) }
$cleanFolder.Add_KeyDown({ if($_.KeyCode -eq [Windows.Forms.Keys]::Enter){ $cleanPreview.PerformClick() } })
$renameFolder.Add_KeyDown({ if($_.KeyCode -eq [Windows.Forms.Keys]::Enter){ $renamePreview.PerformClick() } })
$dupeFolder.Add_KeyDown({ if($_.KeyCode -eq [Windows.Forms.Keys]::Enter){ $scan.PerformClick() } })

[void]$form.ShowDialog()
