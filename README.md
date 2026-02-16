# AudioTranslate

Application Flutter de traduction audio utilisant les API Google Cloud.

## 🎯 Fonctionnalités

- 🎤 **Transcription audio** - Convertit vos fichiers audio en texte
- 🌍 **Traduction multilingue** - Traduit vers 10 langues différentes
- 🔊 **Synthèse vocale** - Génère des fichiers audio WAV avec voix WaveNet
- ✅ **Validation automatique** - Vérifie le format et la taille des fichiers
- 🎨 **Interface intuitive** - Sélection de langue et suivi de progression

## 🏗️ Architecture

- **Clean Architecture** - Séparation Domain/Data/Presentation
- **Riverpod** - Gestion d'état réactive
- **fpdart** - Programmation fonctionnelle (Either/Result pattern)

## 🔧 Technologies

### API Google Cloud (Free Tier)
- **Speech-to-Text API** - 60 minutes/mois gratuit
- **Translation API** - 500,000 caractères/mois gratuit
- **Text-to-Speech API** - 1M caractères/mois gratuit (WaveNet)

### Packages Flutter
- `flutter_riverpod` - State management
- `http` - Client HTTP pour API REST
- `mime` - Détection de type MIME
- `flutter_dotenv` - Gestion des clés API
- `file_picker` - Sélection de fichiers
- `share_plus` - Partage de fichiers

## 📋 Prérequis

1. **Flutter SDK** - Version 3.10.7 ou supérieure
2. **Compte Google Cloud Platform** - Gratuit
3. **Clés API activées** :
   - Cloud Speech-to-Text API
   - Cloud Translation API
   - Cloud Text-to-Speech API

## 🚀 Installation

### 1. Cloner le projet

```bash
git clone <repository-url>
cd audiotranslator
```

### 2. Installer les dépendances

```bash
flutter pub get
```

### 3. Configurer Google Cloud Platform

#### a. Créer un projet
1. Aller sur https://console.cloud.google.com
2. Créer un nouveau projet
3. Activer la facturation (gratuit avec $300 de crédits pour 90 jours)

#### b. Activer les API
Dans la console Google Cloud, activer :
- Cloud Speech-to-Text API
- Cloud Translation API
- Cloud Text-to-Speech API

#### c. Créer une clé API
1. Aller dans **APIs & Services > Credentials**
2. Cliquer sur **Create Credentials > API Key**
3. Copier la clé générée

### 4. Configurer l'application

Créer un fichier `.env` à la racine du projet :

```bash
cp .env.example .env
```

Éditer `.env` et ajouter votre clé API :

```env
GOOGLE_CLOUD_API_KEY=votre_clé_api_ici
```

### 5. Lancer l'application

```bash
flutter run
```

## 📱 Utilisation

1. **Sélectionner une langue** - Choisir la langue de synthèse vocale
2. **Uploader un fichier texte** - Format supporté : `.txt` (taille illimitée)
3. **Attendre le traitement** - Suivi de progression en temps réel
4. **Télécharger le résultat** - Fichier audio WAV de haute qualité

### Support des Textes Longs ✨

L'application utilise un **découpage intelligent** pour les textes longs :

- **Textes courts** (<4,500 caractères) : Génération directe
- **Textes longs** (>4,500 caractères) : 
  - Découpage automatique aux limites naturelles (paragraphes, phrases, ponctuation)
  - Génération audio par segment
  - Concaténation automatique en un seul fichier WAV
  - Messages de progression détaillés ("Génération partie 1/8...", etc.)

### Performances

- **Texte court** (1,000 chars) : ~2-5 secondes
- **Texte moyen** (10,000 chars) : ~6-15 secondes
- **Texte long** (33,000 chars) : ~14-35 secondes

> **Note** : Le découpage respecte les limites naturelles du texte pour garantir une lecture fluide et naturelle de l'audio généré.

## 🌍 Langues Supportées

- 🇫🇷 Français
- 🇬🇧 English
- 🇪🇸 Español
- 🇩🇪 Deutsch
- 🇮🇹 Italiano
- 🇵🇹 Português
- 🇯🇵 日本語
- 🇨🇳 中文
- 🇰🇷 한국어
- 🇸🇦 العربية

## 🔒 Sécurité

- Le fichier `.env` est ignoré par Git (`.gitignore`)
- Les clés API ne sont jamais committées
- Utilisation de HTTPS pour toutes les requêtes API

## 📊 Quotas Free-Tier

| API | Quota Gratuit | Après Dépassement |
|-----|---------------|-------------------|
| Speech-to-Text | 60 min/mois | $0.006/15s |
| Translation | 500K chars/mois | $20/1M chars |
| Text-to-Speech (WaveNet) | 1M chars/mois | $16/1M chars |

💡 **Astuce** : Les nouveaux clients reçoivent $300 de crédits gratuits pendant 90 jours.

## 🛠️ Développement

### Structure du projet

```
lib/
├── core/
│   ├── config/          # Configuration API
│   ├── errors/          # Types d'erreurs
│   └── utils/           # Utilitaires (validation, MIME)
└── features/
    └── translation/
        ├── data/        # Data sources & repositories
        ├── domain/      # Entities, use cases, interfaces
        └── presentation/ # UI, widgets, providers
```

### Analyse du code

```bash
flutter analyze
```

### Tests

```bash
flutter test
```

## 🐛 Dépannage

### Erreur : "API key invalid"
- Vérifiez que votre clé API est correcte dans `.env`
- Vérifiez que les API sont activées dans Google Cloud Console

### Erreur : "Quota exceeded"
- Attendez le mois suivant (quotas mensuels)
- Ou passez à un plan payant

### Erreur : "File too large"
- Compressez votre fichier audio
- Ou découpez-le en segments plus courts (< 10 MB)

### Erreur : "Unsupported format"
- Convertissez votre fichier en MP3, WAV, M4A, FLAC ou OGG

## 📝 Licence

Ce projet est un POC (Proof of Concept) pour démonstration.

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou une pull request.

---

**Good Vibes Project POV** 🎵