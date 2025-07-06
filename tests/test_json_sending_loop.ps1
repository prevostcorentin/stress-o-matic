# Paramètres du script
param(
    [int]$NumberOfRequests = 100, # Nombre total de requêtes (par défaut 100)
    [int]$ParallelRequests = 10, # Nombre de requêtes simultanées (par défaut 10)
    [int]$BatchSize = 100, # Taille des lots pour éviter la saturation
    [int]$DelayBetweenBatches = 1, # Délai en secondes entre les lots (par défaut 1)
    [string]$JsonFile = "data\decp-2025.json", # Chemin vers le fichier JSON (relatif à la racine du projet)
    [string]$ServerUrl = "http://localhost:8080/data", # URL du serveur pour l'envoi des requêtes
    [string]$MetricsUrl = "http://localhost:8080/metrics"  # URL du endpoint metrics
)

# Déterminer le chemin de la racine du projet
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $projectRoot)
{
    $projectRoot = (Get-Location).Path
}

# Construire le chemin complet vers le fichier JSON
$fullJsonPath = Join-Path -Path $projectRoot -ChildPath $JsonFile

# Vérification préalable du fichier JSON
if (-not (Test-Path $fullJsonPath))
{
    Write-Host "ERREUR: Le fichier $fullJsonPath n'existe pas!" -ForegroundColor Red
    Write-Host "Veuillez :"
    Write-Host "1. Créer le dossier 'data' si nécessaire"
    Write-Host "2. Télécharger le fichier decp-2025.json depuis https://www.data.gouv.fr/datasets/donnees-essentielles-de-la-commande-publique-fichiers-consolides/"
    Write-Host "3. Placer le fichier dans le dossier 'data'"
    Write-Host ""
    Write-Host "Ou utilisez un fichier JSON de test avec : -JsonFile 'chemin/vers/votre/fichier.json'"
    exit 1
}

Write-Host "Démarrage du test de charge avec $NumberOfRequests requêtes ($ParallelRequests en parallèle)..."
Write-Host "Fichier utilisé : $fullJsonPath"
Write-Host "URL du serveur : $ServerUrl"
Write-Host "URL des métriques : $MetricsUrl"

# Fonction pour récupérer les métriques du serveur
function Get-ServerMetrics
{
    param (
        [string]$MetricsUrl,
        [int]$StartTime = 0,
        [int]$EndTime = 0
    )

    # Si les temps ne sont pas spécifiés, utiliser une plage large pour récupérer toutes les métriques
    if ($StartTime -le 0 -or $EndTime -le 0)
    {
        # Utiliser une date passée pour start_time (1er janvier 2020)
        $StartTime = 1577836800
        # Utiliser une date future pour end_time (1er janvier 2030)
        $EndTime = 1893456000
    }

    $url = "${MetricsUrl}?start_time=${StartTime}&end_time=${EndTime}"

    try
    {
        $response = & C:\Windows\System32\curl.exe -X GET $url --silent
        return $response
    }
    catch
    {
        Write-Host "Erreur lors de la récupération des métriques : $_" -ForegroundColor Red
        return $null
    }
}

# Fonction pour analyser et afficher les métriques
function Show-Metrics
{
    param (
        [string]$MetricsData,
        [string]$Title = "Métriques du serveur"
    )

    if (-not $MetricsData)
    {
        Write-Host "Aucune donnée de métrique disponible." -ForegroundColor Yellow
        return
    }

    Write-Host "`n=== $Title ===" -ForegroundColor Cyan

    $cpuValues = @()
    $memValues = @()

    $lines = $MetricsData -split "`n"
    foreach ($line in $lines)
    {
        if ($line -match "^cpu_percent\s+([\d\.]+)\s+(\d+)$")
        {
            $cpuValues += [double]$matches[1]
        }
        elseif ($line -match "^mem_mb\s+([\d\.]+)\s+(\d+)$")
        {
            $memValues += [double]$matches[1]
        }
    }

    if ($cpuValues.Count -gt 0)
    {
        $avgCpu = ($cpuValues | Measure-Object -Average).Average
        $maxCpu = ($cpuValues | Measure-Object -Maximum).Maximum
        $minCpu = ($cpuValues | Measure-Object -Minimum).Minimum

        Write-Host "CPU Usage:" -ForegroundColor Green
        Write-Host "  Moyenne: $([Math]::Round($avgCpu, 2) )%" -ForegroundColor White
        Write-Host "  Maximum: $([Math]::Round($maxCpu, 2) )%" -ForegroundColor White
        Write-Host "  Minimum: $([Math]::Round($minCpu, 2) )%" -ForegroundColor White
    }

    if ($memValues.Count -gt 0)
    {
        $avgMem = ($memValues | Measure-Object -Average).Average
        $maxMem = ($memValues | Measure-Object -Maximum).Maximum
        $minMem = ($memValues | Measure-Object -Minimum).Minimum

        Write-Host "Memory Usage:" -ForegroundColor Green
        Write-Host "  Moyenne: $([Math]::Round($avgMem, 2) ) MB" -ForegroundColor White
        Write-Host "  Maximum: $([Math]::Round($maxMem, 2) ) MB" -ForegroundColor White
        Write-Host "  Minimum: $([Math]::Round($minMem, 2) ) MB" -ForegroundColor White
    }

    Write-Host "Nombre d'échantillons: $( $cpuValues.Count )" -ForegroundColor White
}

# Variables pour les statistiques
$startTime = Get-Date
$successCount = 0
$errorCount = 0

## Récupérer les métriques initiales
#Write-Host "Récupération des métriques initiales..." -ForegroundColor Cyan
#$initialMetrics = Get-ServerMetrics -MetricsUrl $MetricsUrl
#Show-Metrics -MetricsData $initialMetrics -Title "MÉTRIQUES INITIALES DU SERVEUR"

# Boucle principale pour envoyer les requêtes par lots
for ($i = 0; $i -lt $NumberOfRequests; $i += $ParallelRequests) {
    $jobs = @()

    # Création des jobs en parallèle
    for ($j = 0; $j -lt $ParallelRequests -and ($i + $j) -lt $NumberOfRequests; $j++) {
        $requestId = $i + $j + 1
        $jobs += Start-Job -ScriptBlock {
            param($requestId, $jsonFile, $serverUrl)
            try
            {
                $result = & C:\Windows\System32\curl.exe -X POST $serverUrl -d "@$jsonFile" --silent
                Write-Host "Requête $requestId terminée"
                return $true
            }
            catch
            {
                Write-Host "Erreur sur la requête $requestId : $_"
                return $false
            }
        } -ArgumentList $requestId, $fullJsonPath, $ServerUrl
    }

    # Attente que tous les jobs du lot soient terminés
    $jobs | Wait-Job | Out-Null

    # Récupération des résultats et comptage des succès/erreurs
    $results = $jobs | Receive-Job
    foreach ($result in $results)
    {
        if ($result -eq $true)
        {
            $successCount++
        }
        else
        {
            $errorCount++
        }
    }

    # Nettoyage des jobs
    $jobs | Remove-Job

    $completedRequests = [Math]::Min($i + $ParallelRequests, $NumberOfRequests)
    Write-Host "Lot terminé. Progression: $completedRequests/$NumberOfRequests requêtes"

    if ($i + $ParallelRequests -lt $NumberOfRequests)
    {
        Write-Host "Pause de $DelayBetweenBatches secondes..."
        Start-Sleep -Seconds $DelayBetweenBatches
    }
}

# Affichage des statistiques finales
$endTime = Get-Date
$totalTime = ($endTime - $startTime).TotalSeconds

Write-Host "`n=== STATISTIQUES DU TEST DE CHARGE ==="
Write-Host "Nombre total de requêtes : $NumberOfRequests"
Write-Host "Requêtes réussies : $successCount"
Write-Host "Requêtes échouées : $errorCount"
Write-Host "Temps total : $([Math]::Round($totalTime, 2) ) secondes"
Write-Host "Débit moyen : $([Math]::Round($NumberOfRequests / $totalTime, 2) ) requêtes/seconde"
Write-Host "Test de charge terminé."

# Récupérer les métriques après le test
Write-Host "`nRécupération des métriques finales..." -ForegroundColor Cyan

# Convertir les dates en timestamps Unix pour l'API metrics
$startTimeUnix = [int][double]::Parse((Get-Date -Date $startTime -UFormat %s))
$endTimeUnix = [int][double]::Parse((Get-Date -Date $endTime -UFormat %s))

# Récupérer les métriques pour la période du test
$testMetrics = Get-ServerMetrics -MetricsUrl $MetricsUrl -StartTime $startTimeUnix -EndTime $endTimeUnix
Show-Metrics -MetricsData $testMetrics -Title "MÉTRIQUES DU SERVEUR PENDANT LE TEST"

# Récupérer les métriques actuelles
$currentMetrics = Get-ServerMetrics -MetricsUrl $MetricsUrl
Show-Metrics -MetricsData $currentMetrics -Title "MÉTRIQUES ACTUELLES DU SERVEUR"


# Créer le dossier data s'il n'existe pas
$dataFolder = Join-Path -Path $projectRoot -ChildPath "data"
if (-not (Test-Path $dataFolder))
{
    New-Item -ItemType Directory -Path $dataFolder
}

# Créer un fichier JSON de test
$testJson = @{
    "test" = "data"
    "timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "items" = @(1..100)
} | ConvertTo-Json

$testJsonPath = Join-Path -Path $projectRoot -ChildPath "data\decp-2025.json"
$testJson | Out-File -FilePath $testJsonPath -Encoding UTF8
Write-Host "Fichier de test utilisé : $testJsonPath"
