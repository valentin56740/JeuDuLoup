# 🐺 Jeu du Loup

Le **Jeu du Loup** repose sur une approche **multi-agent**, où chaque entité (loup ou mouton) agit comme un **agent autonome** capable de percevoir son environnement, de prendre des décisions et d’agir en conséquence.  
Ces interactions locales entre agents (loups et moutons) produisent un **comportement collectif émergent** : les loups coopèrent pour chasser efficacement, tandis que les moutons se déplacent et réagissent de manière indépendante dans leur environnement.

---

## 📋 Table des matières

- [Aperçu](#aperçu)
- [Fonctionnalités](#fonctionnalités)
- [Comportement des Loups](#🐺-comportement-des-loups)
- [Comportement des Moutons](#🐑-comportement-des-moutons)
- [Système Multi-Agent](#🧠-système-multi-agent)
- [Système de Coordination](#🧩-système-de-coordination)
- [Architecture Technique](#architecture-technique)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Comment Jouer](#comment-jouer)
- [Licence](#licence)

---

## 🎮 Aperçu

Le **Jeu du Loup** est une simulation 3D écologique et comportementale où des loups chassent des moutons dans un environnement semi-ouvert.  
L’objectif est de reproduire un **comportement de meute réaliste** grâce à un système de coordination entre les prédateurs et une réaction naturelle des proies.

### Caractéristiques principales

- 🐺 **Chasse intelligente** avec priorités et réservations  
- 🐑 **Réactions naturelles des moutons** : errance, fuite, vigilance  
- 🤝 **Coordination entre loups** (activable/désactivable)  
- 🔄 **Reproduction dynamique** après capture d’une proie (optionnelle)  
- 🎯 **Recherche autonome** quand aucune proie n’est détectée  
- ⚡ **Physique réaliste** : inertie, vitesses limitées, amortissement  

---

## ✨ Fonctionnalités

### 🐺 Comportement des Loups

Les loups sont des agents autonomes dotés d’un comportement de chasse hiérarchisé en trois niveaux de priorité :

1. **Mode Poursuite Proche** (Priorité 1)  
   - Cible le mouton le plus proche.  
   - Ajuste la vitesse pour ne pas dépasser la proie.  
   - Réserve la cible pour éviter les conflits avec d’autres loups.  

2. **Mode Poursuite Lointaine** (Priorité 2)  
   - Se dirige vers une proie détectée à distance.  
   - Vérifie la disponibilité via le système de réservation partagé.  

3. **Mode Recherche** (Priorité 3)  
   - Tourne sur place pour scanner l’environnement.  
   - Active automatiquement quand aucune proie n’est détectée.  

🔧 *Ces comportements peuvent être combinés ou ajustés selon les paramètres du projet Godot.*  

---

### 🐑 Comportement des Moutons

Les moutons sont des agents autonomes capables de percevoir les loups proches et d’adapter leur comportement selon le niveau de danger.

#### 🧭 Modes de comportement

1. **Mode Wander (Errance)**  
   - Le mouton se déplace aléatoirement dans son environnement.  
   - Il alterne entre marche et broutage à intervalles aléatoires.  
   - Pendant le broutage, il reste immobile avec une animation *Idle_Eating*.  

2. **Mode Safe (Sécurité)**  
   - Activé lorsqu’un loup entre dans une **zone de sécurité** (distance moyenne).  
   - Le mouton s’éloigne à vitesse modérée (`safe_speed`).  
   - Si le loup s’éloigne au-delà du rayon de sécurité, il repasse en mode “Wander”.  

3. **Mode Flee (Fuite)**  
   - Activé lorsqu’un loup entre dans une **zone dangereuse** (proximité immédiate).  
   - Le mouton fuit rapidement (`flee_speed`) dans la direction opposée au loup.  
   - L’animation passe automatiquement en *Run*.  
   - Une fois le danger éloigné, il revient au mode “Safe” ou “Wander”.
   - 
4. **Mode Follow (Suivre)**  
   - Lorsque le mouton détecte plus de moutons dans son champ de vision que proche de lui.
   - Le mouton va donc chercher à se regrouper une fois qu'il est plus inquiété par un loup, les modes safe et flee restent prioritaires.   
   - Une fois regroupé le mouton repasse en mode Wander. 
---

## 🧠 Système Multi-Agent

Le **Jeu du Loup** illustre un système **multi-agent distribué** : chaque entité agit localement, mais les interactions entre elles créent une **intelligence collective**.

### 1. Agents autonomes
- Chaque **loup** et **mouton** a son propre cycle de décision et agit indépendamment.  
- Ils réagissent à leurs perceptions locales sans intervention d’un contrôleur global.  

### 2. Interactions entre agents
- **Loups ↔ Moutons** : relations prédateur/proie.  
- **Loups ↔ Loups** : coopération indirecte via le système de réservation.  
- **Moutons ↔ Loups** : détection de zones dangereuses ou sécurisées.

### 3. Coordination distribuée
- Les règles locales sont simples, mais les comportements collectifs sont complexes et cohérents.  
- L’ensemble donne naissance à des dynamiques émergentes (chasse organisée, équilibre écologique...).

---

## 🧩 Système de Coordination

Le **système de réservation** gère la répartition des proies entre les loups de manière **coopérative et non centralisée** :

- 🧱 **Réservation exclusive** : un mouton ne peut être chassé que par un seul loup.  
- 🗂️ **Dictionnaire partagé** : tous les loups accèdent à la même base de données.  
- 🔁 **Nettoyage automatique** : libération d’une proie si un loup disparaît.  
- 🔎 **Vérification continue** : empêche les doublons et garantit la cohérence du système.

⚙️ **Option désactivable :**  
Il est possible de **désactiver le système de coordination** pour observer un comportement plus chaotique, où plusieurs loups peuvent poursuivre la même proie sans communication.  
Cela permet de comparer les dynamiques avec et sans intelligence collective.

---

## 🧬 Reproduction Dynamique

Lorsqu’un loup capture un mouton, il peut — selon la configuration — **se reproduire** et engendrer un nouveau loup.  
Ce mécanisme permet une **évolution naturelle du nombre de prédateurs** en fonction du succès de la chasse.

⚙️ **Option désactivable :**  
La reproduction peut être désactivée pour maintenir un équilibre fixe entre les espèces.

---

## 🧱 Architecture Technique

- Moteur : **Godot Engine 4.5**  
- Langage : **GDScript**  
- Agents : `RigidBody3D` avec animations (`AnimationPlayer`)  
- Systèmes intégrés :
  - Zones de détection (`Area3D`) pour perception
  - Réservation globale via dictionnaire partagé
  - Physique temps réel et forces appliquées

