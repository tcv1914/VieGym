$ErrorActionPreference = 'Stop'
$baseUrl = 'https://viendinhduong.vn'
$items = [Collections.Generic.List[object]]::new()
$pages = [Collections.Generic.List[object]]::new()
$expected = $null
$page = 1
do {
    $url = "$baseUrl/api/fe/tool/getPageFoodData?page=$page&pageSize=2000"
    $response = $null
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $response = Invoke-RestMethod -Uri $url -TimeoutSec 60
            break
        } catch {
            if ($attempt -eq 3) { throw }
            Start-Sleep -Seconds 2
        }
    }
    if ($null -eq $expected) { $expected = [int]$response.total }
    if ([int]$response.total -ne $expected) { throw 'Source total changed during crawl; retry.' }
    if ([int]$response.current_page -ne $page) { throw 'Unexpected page returned.' }
    foreach ($item in $response.data) { $items.Add($item) }
    $pages.Add([ordered]@{ url = $url; count = @($response.data).Count })
    Write-Host "Page ${page}/$($response.last_page): $($items.Count)/$expected"
    $page++
    if ($page -le [int]$response.last_page) { Start-Sleep -Milliseconds 300 }
} while ($page -le [int]$response.last_page)
if ($items.Count -ne $expected) { throw "Expected $expected records, received $($items.Count)." }
$unique = @($items | ForEach-Object { $_._id } | Sort-Object -Unique)
if ($unique.Count -ne $expected) { throw 'Missing or duplicate record IDs.' }
$regions = Invoke-RestMethod "$baseUrl/api/fe/food/regions" -TimeoutSec 60
$categories = Invoke-RestMethod "$baseUrl/api/fe/tool/apiGetListFoodCategory" -TimeoutSec 60
$result = [ordered]@{
    source_url = "$baseUrl/vi/cong-cu-va-tien-ich/gia-tri-dinh-duong-mon-an"
    retrieved_at = [DateTimeOffset]::UtcNow.ToString('o')
    total = $items.Count
    notes = 'Original API fields and empty values are preserved. Image paths are relative to https://viendinhduong.vn; image binaries are not embedded.'
    pages = $pages.ToArray()
    regions = $regions
    categories = $categories
    data = $items.ToArray()
}
$outputPath = Join-Path $PSScriptRoot 'viendinhduong_mon_an.json'
$json = $result | ConvertTo-Json -Depth 100
[IO.File]::WriteAllText($outputPath, $json, [Text.UTF8Encoding]::new($false))
$verified = Get-Content -LiteralPath $outputPath -Raw -Encoding utf8 | ConvertFrom-Json
if (@($verified.data).Count -ne $expected) { throw 'Output verification failed.' }
Write-Host "Saved and verified: $outputPath ($expected records)"
