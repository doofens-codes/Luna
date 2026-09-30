# lunasim_godot 🌙

An elementary Godot engine simulation designed to understand, visualize, and analyze shadow behavior on the lunar surface. 

This repository serves as a foundational prototype built for the **Smart India Hackathon (SIH) Project**, focusing on space technology applications and lunar terrain data synthesis.

## 📌 Project Overview
Analyzing surface conditions is critical for planning rover traversal paths and locating future landing sites. This project establishes a correspondence framework using lunar imagery captured by **ISRO's Chandrayaan-2 Orbiter** payloads—specifically leveraging high-resolution topography references from the **Terrain Mapping Camera-2 (TMC-2)** and the **Orbiter High Resolution Camera (OHRC)**.

The primary objective of this Godot simulator is to map dynamic lighting angles against 3D lunar surface assets, providing an accessible simulation tool for observing how shadows shift over craters, scarps, and permanently shadowed regions (PSRs).

## 🚀 Features
* **Dynamic Lighting Simulation:** Replicates changing solar incidence angles to model illumination profiles on the lunar landscape.
* **TMC-2 & OHRC Data Correspondence:** Designed to correspond with high-resolution panchromatic mapping datasets provided by ISRO.
* **Light & Shadow Analysis:** Helps identify areas of steep viewing angles, illumination drop-offs, and potential cold-trap shadow behaviors.
* **Built in Godot:** Utilizing Godot's real-time 3D rendering pipeline for efficient, lightweight prototyping.

## 🛠️ Tech Stack & Requirements
* **Game Engine:** Godot Engine 4.x (Standard Edition)
* **Environment:** Cross-platform (Optimized for Fedora Linux / Vulkan / OpenGL backends)
* **Source Data Attributes:** Inspired by Chandrayaan-2 data profiles (5m spatial resolution maps & digital elevation models).

## 📁 Getting Started
1. Clone the repository:
   ```bash
   git clone git@github.com:doofens-codes/lunasim_godot.git
   ```
2. Open the **Godot Engine** and click **Import**.
3. Select the `project.godot` file inside this repository directory.
4. Run the main scene (`F5`) to interact with the lunar illumination matrix.

---
*Disclaimer: This is an elementary physics and rendering simulation built for academic research and prototype validation under the SIH hackathon scope.*
