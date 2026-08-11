param(
    [Parameter(Mandatory = $true)]
    [string]$Workspace,

    [string]$Title = 'MyP-M-A 行为评测对照',
    [string]$BaselineLabel = '基线版本',
    [string]$CandidateLabel = '候选版本',
    [string]$OutputPath = 'eval-viewer.html',
    [string]$StabilityNote = '',
    [string]$SuiteLabel = '高区分度挑战集',
    [string]$ExecutionNote = '独立执行与评分'
)

$ErrorActionPreference = 'Stop'
$workspacePath = (Resolve-Path -LiteralPath $Workspace -ErrorAction Stop).Path
$iteration = Get-Content -LiteralPath (Join-Path $workspacePath 'iteration.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$benchmark = Get-Content -LiteralPath (Join-Path $workspacePath 'benchmark-lite.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$baselineSummary = @($benchmark.summary | Where-Object { $_.configuration -eq 'baseline' })[0]
$candidateSummary = @($benchmark.summary | Where-Object { $_.configuration -eq 'candidate' })[0]
$pairedSummary = $benchmark.paired_summary
$qualityReportPath = Join-Path $workspacePath 'quality-report.json'
$qualityReport = if (Test-Path -LiteralPath $qualityReportPath -PathType Leaf) {
    Get-Content -LiteralPath $qualityReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $null
}
$qualityCasesById = @{}
if ($null -ne $qualityReport) {
    foreach ($qualityCase in @($qualityReport.cases)) {
        $qualityCasesById[[string]$qualityCase.eval_id] = $qualityCase
    }
}
Write-Host 'Viewer: loading evaluation files'

function Get-CaseDisplayName {
    param(
        [Parameter(Mandatory = $true)]$Metadata,
        [Parameter(Mandatory = $true)][string]$Fallback
    )

    $title = [string]$Metadata.display_name
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = [string]$Metadata.expected_output
    }
    if ([string]::IsNullOrWhiteSpace($title)) {
        return $Fallback
    }

    $title = $title.Trim()
    $title = $title -replace '^应(?:当|该)?', ''
    $title = $title -replace 'project\s+review', '项目评审'
    $title = $title -replace 'page\s+review', '页面评审'
    $title = $title -replace 'PRD\s+review', 'PRD 评审'
    $title = $title -replace 'Basic\s+Memory', 'Basic Memory 长期记忆库'
    $title = $title -replace 'Memory-only', '仅作长期记忆候选'
    $title = $title -replace 'stale\s+candidate', '过期候选'
    $title = $title -replace '\bMemory\b', '长期记忆'
    $title = $title -replace '\bbackend\b', '后端'
    $title = $title -replace '\bfrontend\b', '前端'
    $title = $title -replace '\bscorecard\b', '评分卡'
    $title = $title -replace '\bzero-shot\b', '零样本'
    $title = $title -replace 'tag/Release', '标签与发布页'
    $title = @($title -split '[，；。\r\n]')[0].Trim()
    if ($title.Length -gt 36) {
        $title = $title.Substring(0, 36) + '…'
    }
    return $title
}

function Get-RunDuration {
    param([Parameter(Mandatory = $true)][string]$RunDirectory)
    $executionPath = Join-Path $RunDirectory 'execution.json'
    if (-not (Test-Path -LiteralPath $executionPath -PathType Leaf)) { return $null }
    try {
        $execution = Get-Content -LiteralPath $executionPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $execution.duration_ms -and [double]$execution.duration_ms -ge 0) {
            return [Math]::Round([double]$execution.duration_ms, 1)
        }
    } catch {
        return $null
    }
    return $null
}

$cases = foreach ($directoryName in @($iteration.eval_directories)) {
    $evalDirectory = Join-Path $workspacePath $directoryName
    $task = Get-Content -LiteralPath (Join-Path $evalDirectory 'task.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $metadata = Get-Content -LiteralPath (Join-Path $workspacePath "$($iteration.grader_directory)\$directoryName.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $baselineDirectory = Join-Path $evalDirectory 'baseline\run-1'
    $candidateDirectory = Join-Path $evalDirectory 'candidate\run-1'
    $baselineResponse = [System.IO.File]::ReadAllText(
        (Join-Path $baselineDirectory 'response.md'),
        [System.Text.Encoding]::UTF8
    )
    $candidateResponse = [System.IO.File]::ReadAllText(
        (Join-Path $candidateDirectory 'response.md'),
        [System.Text.Encoding]::UTF8
    )
    $baselineGrade = Get-Content -LiteralPath (Join-Path $baselineDirectory 'grading.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $candidateGrade = Get-Content -LiteralPath (Join-Path $candidateDirectory 'grading.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $baselineExpectations = @($baselineGrade.expectations | ForEach-Object {
        [ordered]@{ text = [string]$_.text; passed = [bool]$_.passed; evidence = [string]$_.evidence }
    })
    $candidateExpectations = @($candidateGrade.expectations | ForEach-Object {
        [ordered]@{ text = [string]$_.text; passed = [bool]$_.passed; evidence = [string]$_.evidence }
    })
    $qualityCase = if ($qualityCasesById.ContainsKey([string]$task.id)) { $qualityCasesById[[string]$task.id] } else { $null }

    $beforeResponsePath = Join-Path $candidateDirectory 'response-before-review-fix.md'
    $beforeGradePath = Join-Path $candidateDirectory 'grading-before-review-fix.json'
    $beforeFix = $null
    if ((Test-Path -LiteralPath $beforeResponsePath) -and (Test-Path -LiteralPath $beforeGradePath)) {
        $beforeGrade = Get-Content -LiteralPath $beforeGradePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $beforeFix = [ordered]@{
            response = [System.IO.File]::ReadAllText($beforeResponsePath, [System.Text.Encoding]::UTF8)
            passed = [int]$beforeGrade.summary.passed
            total = [int]$beforeGrade.summary.total
        }
    }

    [ordered]@{
        id = [string]$task.id
        name = Get-CaseDisplayName -Metadata $metadata -Fallback ([string]$task.name)
        machine_name = [string]$task.name
        prompt = [string]$task.prompt
        baseline = [ordered]@{
            response = $baselineResponse
            chars = $baselineResponse.Length
            passed = [int]$baselineGrade.summary.passed
            total = [int]$baselineGrade.summary.total
            expectations = $baselineExpectations
            duration_ms = Get-RunDuration -RunDirectory $baselineDirectory
        }
        candidate = [ordered]@{
            response = $candidateResponse
            chars = $candidateResponse.Length
            passed = [int]$candidateGrade.summary.passed
            total = [int]$candidateGrade.summary.total
            expectations = $candidateExpectations
            duration_ms = Get-RunDuration -RunDirectory $candidateDirectory
        }
        before_fix = $beforeFix
        quality = $qualityCase
    }
}

$data = [ordered]@{
    title = $Title
    suite_label = $SuiteLabel
    execution_note = $ExecutionNote
    case_count = @($cases).Count
    baseline_label = $BaselineLabel
    candidate_label = $CandidateLabel
    stability_note = $StabilityNote
    quality = $qualityReport
    summary = [ordered]@{
        baseline_passed = [int]$baselineSummary.passed
        baseline_total = [int]$baselineSummary.total
        baseline_rate = [double]$baselineSummary.pass_rate
        baseline_chars = [double]$baselineSummary.average_response_chars
        baseline_complete = [int]$baselineSummary.complete_runs
        baseline_expected = [int]$baselineSummary.expected_runs
        candidate_passed = [int]$candidateSummary.passed
        candidate_total = [int]$candidateSummary.total
        candidate_rate = [double]$candidateSummary.pass_rate
        candidate_chars = [double]$candidateSummary.average_response_chars
        candidate_complete = [int]$candidateSummary.complete_runs
        candidate_expected = [int]$candidateSummary.expected_runs
        paired_complete = if ($null -eq $pairedSummary) { [Math]::Min([int]$baselineSummary.complete_runs, [int]$candidateSummary.complete_runs) } else { [int]$pairedSummary.complete_pairs }
        paired_expected = if ($null -eq $pairedSummary) { [int]$baselineSummary.expected_runs } else { [int]$pairedSummary.expected_pairs }
        paired_baseline_passed = if ($null -eq $pairedSummary) { [int]$baselineSummary.passed } else { [int]$pairedSummary.baseline_passed }
        paired_candidate_passed = if ($null -eq $pairedSummary) { [int]$candidateSummary.passed } else { [int]$pairedSummary.candidate_passed }
        paired_total = if ($null -eq $pairedSummary) { [int]$baselineSummary.total } else { [int]$pairedSummary.total }
        paired_baseline_chars = if ($null -eq $pairedSummary) { [double]$baselineSummary.average_response_chars } else { [double]$pairedSummary.baseline_average_response_chars }
        paired_candidate_chars = if ($null -eq $pairedSummary) { [double]$candidateSummary.average_response_chars } else { [double]$pairedSummary.candidate_average_response_chars }
        baseline_wins = if ($null -eq $pairedSummary) { 0 } else { [int]$pairedSummary.baseline_wins }
        candidate_wins = if ($null -eq $pairedSummary) { 0 } else { [int]$pairedSummary.candidate_wins }
        ties = if ($null -eq $pairedSummary) { 0 } else { [int]$pairedSummary.ties }
    }
    cases = @($cases)
}

Write-Host 'Viewer: serializing data'
$json = ($data | ConvertTo-Json -Depth 6 -Compress).Replace('</', '<\/')
Write-Host "Viewer: serialized chars=$($json.Length)"
$html = @'
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>__TITLE__</title>
  <style>
    :root{--bg:#f3f2ed;--paper:#fffefb;--ink:#19201e;--muted:#66706c;--line:#d8d9d3;--accent:#cf6036;--accent-soft:#f8e3da;--green:#247257;--green-soft:#e3f1ea;--red:#b43f39;--red-soft:#f8e4e1;--blue:#365f83;--blue-soft:#e6eef5;--shadow:0 10px 28px rgba(25,32,30,.07)}
    *{box-sizing:border-box}html{background:var(--bg);color:var(--ink)}body{margin:0;font-family:"Segoe UI","Microsoft YaHei UI",sans-serif;font-size:14px;letter-spacing:0}button{font:inherit;letter-spacing:0}.top{background:var(--ink);color:#fff;padding:20px 28px}.topin{max-width:1500px;margin:auto;display:flex;justify-content:space-between;gap:20px;align-items:flex-end}.eyebrow{color:#f3ac8d;font-size:12px;font-weight:700}.top h1{margin:5px 0 0;font-size:24px}.topmeta{color:#c6ceca;text-align:right;line-height:1.6}.summary{max-width:1500px;margin:18px auto 0;padding:0 28px;display:grid;grid-template-columns:1.5fr repeat(5,minmax(112px,.55fr));gap:10px}.card{background:var(--paper);border:1px solid var(--line);border-radius:6px;box-shadow:var(--shadow);padding:16px}.verdict b{display:block;color:var(--green);font-size:18px;margin-bottom:5px}.verdict span{color:var(--muted);line-height:1.55}.metric b{font-size:22px;font-variant-numeric:tabular-nums}.metric small{display:block;color:var(--muted);margin-top:4px}.quality{max-width:1500px;margin:12px auto 0;padding:0 28px}.quality-grid{display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:10px}.quality-card{background:var(--paper);border:1px solid var(--line);border-radius:6px;padding:13px;box-shadow:var(--shadow)}.quality-card b{display:block;font-size:16px;margin-bottom:5px}.quality-card small{color:var(--muted);line-height:1.45}.layout{max-width:1500px;margin:auto;padding:18px 28px 38px;display:grid;grid-template-columns:270px minmax(0,1fr);gap:18px}.rail{position:sticky;top:16px;align-self:start;background:var(--paper);border:1px solid var(--line);border-radius:6px;box-shadow:var(--shadow);overflow:hidden}.railhead{padding:12px 14px;color:var(--muted);font-size:12px;font-weight:700;border-bottom:1px solid var(--line)}.casebtn{width:100%;border:0;border-bottom:1px solid var(--line);background:transparent;padding:11px 13px;display:grid;grid-template-columns:44px 1fr auto;gap:8px;text-align:left;cursor:pointer}.casebtn:last-child{border-bottom:0}.casebtn:hover{background:#f8f7f2}.casebtn.active{background:var(--accent-soft);box-shadow:inset 3px 0 var(--accent)}.caseid{color:var(--accent);font-weight:750}.casename{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.score{color:var(--muted);font-size:12px}.content{min-width:0;display:flex;flex-direction:column;gap:14px}.panel,.answer{background:var(--paper);border:1px solid var(--line);border-radius:6px;box-shadow:var(--shadow);overflow:hidden}.panelhead,.answerhead{padding:12px 14px;background:#faf9f5;border-bottom:1px solid var(--line);display:flex;justify-content:space-between;gap:12px;align-items:center}.panelhead h2{font-size:15px;margin:0}.panelbody{padding:14px}.prompt{white-space:pre-wrap;line-height:1.65}.answers{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.answerhead b{font-size:14px}.answerhead span{color:var(--muted);font-variant-numeric:tabular-nums}.answer pre{margin:0;padding:15px;max-height:590px;overflow:auto;white-space:pre-wrap;word-break:break-word;font:13px/1.62 Consolas,"Microsoft YaHei UI",monospace}.badge{display:inline-flex;padding:3px 8px;border-radius:999px;font-size:12px;font-weight:750}.good{background:var(--green-soft);color:var(--green)}.bad{background:var(--red-soft);color:var(--red)}.same{background:var(--blue-soft);color:var(--blue)}table{width:100%;border-collapse:collapse;table-layout:fixed}th,td{padding:10px 11px;border-bottom:1px solid var(--line);vertical-align:top;text-align:left;line-height:1.5}th{background:#faf9f5;color:var(--muted);font-size:12px}tr:last-child td{border-bottom:0}.rule{width:38%}.version{width:31%}.status{font-weight:800;margin-right:6px}.pass{color:var(--green)}.fail{color:var(--red)}.failcell{background:var(--red-soft)}.note{margin-top:10px;padding:10px 12px;border-left:3px solid var(--accent);background:#fff6f1;color:#75412e;line-height:1.6}.muted{color:var(--muted)}
    @media(max-width:1000px){.summary{grid-template-columns:repeat(2,1fr)}.verdict{grid-column:1/-1}.quality-grid{grid-template-columns:repeat(2,1fr)}.layout{grid-template-columns:1fr}.rail{position:static;display:flex;overflow-x:auto}.railhead{display:none}.casebtn{min-width:205px;border-right:1px solid var(--line);border-bottom:0}.answers{grid-template-columns:1fr}}@media(max-width:650px){.topin{align-items:flex-start;flex-direction:column}.topmeta{text-align:left}.summary,.quality{padding:0 14px}.quality-grid{grid-template-columns:1fr}.layout{padding:14px}.metric b{font-size:18px}table,tbody,tr,td{display:block;width:100%}thead{display:none}td::before{content:attr(data-label);display:block;color:var(--muted);font-size:11px;font-weight:700;margin-bottom:4px}}
  </style>
</head>
<body>
  <header class="top"><div class="topin"><div><div class="eyebrow" id="suite-label"></div><h1 id="title"></h1></div><div class="topmeta" id="topmeta"></div></div></header>
  <section class="summary">
    <div class="card verdict"><b id="verdict"></b><span id="summary-note"></span></div>
    <div class="card metric"><b id="base-score"></b><small id="base-label"></small></div>
    <div class="card metric"><b id="cand-score"></b><small id="cand-label"></small></div>
    <div class="card metric"><b id="delta"></b><small>通过率提升</small></div>
    <div class="card metric"><b id="completion"></b><small>SLA 有效返回</small></div>
    <div class="card metric"><b id="chars"></b><small>候选平均字符变化</small></div>
  </section>
  <section class="quality" id="quality-section" hidden><div class="quality-grid" id="quality-grid"></div></section>
  <main class="layout"><nav class="rail"><div class="railhead" id="suite-nav"></div><div id="case-list"></div></nav><div class="content">
    <section class="panel"><div class="panelhead"><h2 id="case-title"></h2><span id="case-verdict"></span></div><div class="panelbody"><div id="prompt" class="prompt"></div><div id="fix-note"></div></div></section>
    <section class="answers" id="answers"></section>
    <section class="panel" id="quality-detail-panel" hidden><div class="panelhead"><h2>交付质量配对判断</h2><span class="badge same">独立维度，不设综合分</span></div><div style="overflow:auto"><table><thead><tr><th>维度</th><th>胜负</th><th>样本内证据</th></tr></thead><tbody id="quality-detail"></tbody></table></div></section>
    <section class="panel"><div class="panelhead"><h2>逐条断言与证据</h2><span class="badge same">严格布尔评分</span></div><div style="overflow:auto"><table><thead><tr><th class="rule">断言</th><th class="version" id="base-th"></th><th class="version" id="cand-th"></th></tr></thead><tbody id="assertions"></tbody></table></div></section>
  </div></main>
  <script>
    const data=__DATA__;let selected=0;const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));const pct=v=>(v*100).toFixed(1)+'%';
    function init(){const s=data.summary,baseRate=s.paired_total?s.paired_baseline_passed/s.paired_total:0,candRate=s.paired_total?s.paired_candidate_passed/s.paired_total:0,delta=(candRate-baseRate)*100,charDelta=s.paired_baseline_chars?(s.paired_candidate_chars/s.paired_baseline_chars-1)*100:0;document.querySelector('#title').textContent=data.title;document.title=data.title;document.querySelector('#suite-label').textContent=data.suite_label;document.querySelector('#suite-nav').textContent=data.suite_label;document.querySelector('#topmeta').textContent=`${data.case_count} 个用例 · ${data.execution_note}`;document.querySelector('#verdict').textContent=delta>0?'候选版本共同样本表现更强':delta<0?'候选版本共同样本存在回退':'候选版本与基线共同样本同分';document.querySelector('#summary-note').textContent=data.stability_note||`共同有效 ${s.paired_complete}/${s.paired_expected}；胜负为 ${s.baseline_wins}-${s.candidate_wins}-${s.ties}（基线-候选-平）。`;document.querySelector('#base-score').textContent=`${s.paired_baseline_passed} / ${s.paired_total}`;document.querySelector('#cand-score').textContent=`${s.paired_candidate_passed} / ${s.paired_total}`;document.querySelector('#base-label').textContent=data.baseline_label;document.querySelector('#cand-label').textContent=data.candidate_label;document.querySelector('#delta').textContent=(delta>=0?'+':'')+delta.toFixed(1)+'pp';document.querySelector('#completion').textContent=`${s.baseline_complete}/${s.baseline_expected} · ${s.candidate_complete}/${s.candidate_expected}`;document.querySelector('#chars').textContent=(charDelta>=0?'+':'')+charDelta.toFixed(1)+'%';document.querySelector('#base-th').textContent=data.baseline_label;document.querySelector('#cand-th').textContent=data.candidate_label;renderQualitySummary();render()}
    function qualityWins(v){return `基 ${v.baseline_wins} · 候 ${v.candidate_wins} · 平 ${v.ties}`}
    function qualityCard(label,value,note){return `<div class="quality-card"><b>${esc(value)}</b><small>${esc(label)}${note?` · ${esc(note)}`:''}</small></div>`}
    function renderQualitySummary(){if(!data.quality)return;const q=data.quality.dimensions,d=q.duration_ms,c=q.response_chars,charDelta=c.candidate_change_ratio==null?'unavailable':`${c.candidate_change_ratio>=0?'+':''}${(c.candidate_change_ratio*100).toFixed(1)}%`,duration=d.state==='available'?`${d.baseline_median} → ${d.candidate_median} ms`:'unavailable';document.querySelector('#quality-section').hidden=false;document.querySelector('#quality-grid').innerHTML=qualityCard('正确性',`${q.correctness.baseline_passed}/${q.correctness.total} → ${q.correctness.candidate_passed}/${q.correctness.total}`,'硬门禁')+qualityCard('决策清晰度',qualityWins(q.decision_clarity),'盲评')+qualityCard('重复度',qualityWins(q.redundancy),'盲评')+qualityCard('可执行性',qualityWins(q.actionability),'盲评')+qualityCard('字符数',charDelta,'只报告变化')+qualityCard('完成时长',duration,d.state)+qualityCard('有效返回率',`${(q.valid_return_rate.baseline*100).toFixed(0)}% → ${(q.valid_return_rate.candidate*100).toFixed(0)}%`,'独立报告')}
    function renderList(){document.querySelector('#case-list').innerHTML=data.cases.map((x,i)=>`<button class="casebtn ${i===selected?'active':''}" data-i="${i}"><span class="caseid">${esc(x.id)}</span><span class="casename" title="${esc(x.name)}">${esc(x.name)}</span><span class="score">${x.baseline.passed}:${x.candidate.passed}</span></button>`).join('');document.querySelectorAll('.casebtn').forEach(b=>b.onclick=()=>{selected=Number(b.dataset.i);render()})}
    function cell(e,label){return `<td data-label="${esc(label)}" class="${e.passed?'':'failcell'}"><span class="status ${e.passed?'pass':'fail'}">${e.passed?'通过':'未通过'}</span>${esc(e.evidence||'')}</td>`}
    function renderQualityCase(x){const panel=document.querySelector('#quality-detail-panel');if(!x.quality){panel.hidden=true;return}panel.hidden=false;const labels={decision_clarity:'决策清晰度',redundancy:'重复度',actionability:'可执行性'},wins={baseline:data.baseline_label,candidate:data.candidate_label,tie:'平'};document.querySelector('#quality-detail').innerHTML=x.quality.comparisons.map(v=>`<tr><td data-label="维度">${esc(labels[v.dimension]||v.dimension)}</td><td data-label="胜负"><span class="badge ${v.winner==='candidate'?'good':v.winner==='baseline'?'bad':'same'}">${esc(wins[v.winner]||v.winner)}</span></td><td data-label="证据">${esc(v.evidence)}</td></tr>`).join('')}
    function render(){renderList();const x=data.cases[selected],d=x.candidate.passed-x.baseline.passed;document.querySelector('#case-title').textContent=`${x.id} · ${x.name}`;document.querySelector('#case-verdict').innerHTML=d>0?'<span class="badge good">候选更优</span>':d<0?'<span class="badge bad">基线更优</span>':'<span class="badge same">同分</span>';document.querySelector('#prompt').textContent=x.prompt;document.querySelector('#fix-note').innerHTML=x.before_fix?`<div class="note"><b>修复复验：</b>候选版修复前为 ${x.before_fix.passed}/${x.before_fix.total}；修复前回答与评分已归档。</div>`:'';document.querySelector('#answers').innerHTML=answer(x.baseline,data.baseline_label)+answer(x.candidate,data.candidate_label);renderQualityCase(x);document.querySelector('#assertions').innerHTML=x.baseline.expectations.map((a,i)=>`<tr><td data-label="断言">${esc(a.text)}</td>${cell(a,data.baseline_label)}${cell(x.candidate.expectations[i],data.candidate_label)}</tr>`).join('')}
    function answer(x,label){const duration=x.duration_ms==null?'时长 unavailable':`${x.duration_ms} ms`;return `<article class="answer"><div class="answerhead"><b>${esc(label)}</b><span>${x.passed}/${x.total} · ${x.chars} 字符 · ${duration}</span></div><pre>${esc(x.response)}</pre></article>`}
    init();
  </script>
</body>
</html>
'@

$html = $html.Replace('__DATA__', $json).Replace('__TITLE__', $Title)
Write-Host "Viewer: assembled chars=$($html.Length)"
$resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $workspacePath $OutputPath }
[System.IO.File]::WriteAllText($resolvedOutput, $html, [System.Text.UTF8Encoding]::new($false))
Write-Host "Eval viewer generated: $resolvedOutput"
