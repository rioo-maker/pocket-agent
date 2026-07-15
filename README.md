# PocketAgent

Agent de code IA dans un terminal, sur ton téléphone Android. Comme OpenCode ou Claude Code, mais en app mobile. L'agent lit, écrit et modifie des fichiers sur le téléphone, exécute des commandes shell et fait du web fetch.

## Fonctionnalités

- Terminal IA avec streaming, 2 skins au choix : **Claude Code** (sombre + orange corail) ou **OpenCode** (noir minimal)
- Outils agent : `read_file`, `write_file`, `edit_file`, `list_dir`, `run_command` (shell Android), `web_fetch`, `search_files`
- Fournisseurs préconfigurés : **Ollama Cloud** (`https://ollama.com/v1` + clé + nom exact du modèle), **Ollama Local/réseau** (`http://IP:11434/v1`), OpenAI, Anthropic, OpenRouter, ou **API personnalisée** (OpenAI-compatible ou Anthropic-compatible : endpoint + clé + modèle)
- Multi-modèles / multi-clés avec **priorité par glisser-déposer** : si une clé est épuisée ou en erreur (401/429/5xx), bascule automatique sur le modèle suivant
- Clés API chiffrées (Android Keystore via `flutter_secure_storage`)
- Onboarding plug-and-play : skin → clé + modèle → prêt
- Workspace choisissable (dossier où l'agent travaille)

## Pourquoi pas un "vrai" Termux avec opencode/claude installés ?

Google Play bloque l'exécution de binaires téléchargés (politique W^X, target SDK récent) — c'est pour ça que Termux du Play Store est cassé. PocketAgent implémente donc sa propre boucle agentique nativement dans l'app : 100% conforme Play Store, léger, et plug-and-play.

## Build

### Option A — GitHub Actions (aucune installation)

1. Pousse ce dossier sur un repo GitHub
2. L'action `.github/workflows/build.yml` se lance automatiquement (ou onglet Actions → Run workflow)
3. Récupère `PocketAgent-APK` (test direct) et `PocketAgent-AAB` (Play Store) dans les artifacts

### Option B — En local

Prérequis : [Flutter](https://docs.flutter.dev/get-started/install) + Android SDK.

```bash
cd pocket_agent
flutter create . --org com.rafael.pocketagent --platforms android --project-name pocket_agent
flutter pub get
flutter build apk --release        # APK de test
flutter build appbundle --release  # AAB pour le Play Store
```

Sorties : `build/app/outputs/flutter-apk/app-release.apk` et `build/app/outputs/bundle/release/app-release.aab`.

## Signature pour le Play Store

Le Play Store exige un AAB signé avec ta propre clé :

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Crée `android/key.properties` :

```
storePassword=TON_MDP
keyPassword=TON_MDP
keyAlias=upload
storeFile=upload-keystore.jks
```

Puis dans `android/app/build.gradle`, ajoute avant `android {` :

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

et dans `android { ... }` :

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

Rebuild `flutter build appbundle --release` → AAB signé prêt pour la Play Console.

## Publication Play Store (résumé)

1. Compte développeur Google Play (25 $ une fois) : https://play.google.com/console
2. Créer l'app → remplir fiche (nom PocketAgent, description, captures, icône 512px)
3. Politique de confidentialité obligatoire (l'app stocke les clés localement, n'envoie rien à un serveur tiers autre que les endpoints IA configurés par l'utilisateur)
4. Uploader l'AAB signé dans une release (test interne d'abord, puis production)
5. Questionnaire "Sécurité des données" : déclarer que les clés API restent sur l'appareil

## Architecture

```
lib/
├── main.dart                    # entrée, thème, routing onboarding/terminal
├── app_state.dart               # état global (skin, routes modèles, workspace)
├── models/
│   ├── provider_config.dart     # ModelRoute (endpoint+clé+modèle+priorité), presets
│   └── chat_message.dart        # messages terminal + format LLM
├── services/
│   ├── llm_client.dart          # streaming SSE OpenAI-compat + Anthropic, failover
│   ├── agent_engine.dart        # boucle agentique (modèle → outils → modèle...)
│   ├── agent_tools.dart         # outils fichiers/shell/web
│   └── storage_service.dart     # persistance (clés chiffrées)
└── ui/
    ├── theme.dart               # skins Claude Code / OpenCode
    └── screens/                 # onboarding, terminal, providers, settings
```
