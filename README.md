# Sistema de Reportes Comunitarios

Aplicación móvil desarrollada con Flutter y Firebase que permite a los ciudadanos reportar problemas comunitarios como inseguridad, contaminación, convivencia y servicios básicos.

El sistema integra Inteligencia Artificial para mejorar la calidad de los reportes mediante:

* clasificación automática de incidencias

* detección de lenguaje ofensivo

* detección de reportes duplicados


# Objetivo del proyecto

Desarrollar una aplicación móvil Full Stack soportada por Inteligencia Artificial y basada en una arquitectura de software Serverless, escalable y modular, que permita a los vecinos y administradores de comunidades gestionar reportes de seguridad ciudadana de manera estructurada, garantizando la integridad de la información mediante herramientas digitales inteligentes de moderación de contenido y detección de duplicidad. 

# Tecnologías utilizadas

**Frontend**

* Flutter

* Riverpod (gestión de estado)

* Hive (almacenamiento local)

* Material Design

**Backend / Cloud**

* Firebase Authentication

* Cloud Firestore

* Firebase Cloud Functions

* Firebase Storage

* Firebase Cloud Messaging

**Inteligencia Artificial**

* API de Hugging Face

* Modelos de análisis semántico

* Clasificación de texto

* Detección de similitud textual

# Funcionalidades con Inteligencia Artificial

**1. Sugerencia automática del tipo de problema**

Mientras el usuario escribe un reporte, la IA analiza el texto y sugiere automáticamente la categoría correspondiente:

* Inseguridad

* Contaminación

* Servicios Básicos

* Convivencia

Esto mejora la clasificación de los reportes.

**2. Detección de lenguaje ofensivo**

Antes de guardar un reporte, el sistema analiza el contenido y detecta palabras ofensivas.

Si se detecta lenguaje inapropiado:

* el sistema bloquea el envío

* se muestran las palabras detectadas

* el usuario debe corregir el texto

**3. Detección de reportes duplicados**

El sistema evita que se registren reportes repetidos.

Proceso:

1. Se aplica un filtro de similitud textual (Jaccard)

1. Si hay coincidencia alta, se usa IA para calcular similitud semántica

1. Si el reporte es similar, se muestra una advertencia al usuario

# Funcionalidades principales

✔ Registro de usuarios

✔ Inicio de sesión seguro

✔ Roles de usuario (Vecino, Administrador, Seguridad)

✔ Creación de reportes comunitarios

✔ Edición de reportes

✔ Visualización de reportes

✔ Notificaciones push

✔ Funcionamiento parcial offline

✔ Sincronización automática

✔ Detección de duplicados mediante IA

✔ Detección de lenguaje ofensivo

✔ Clasificación automática de reportes

# Estructura del Proyecto
```
functions
 ┣ 📂node_modules
 ┣ 📜.gitignore
 ┣ 📜index.js
 ┣ 📜package-lock.json
 ┣ 📜package.json

lib
 ┣ 📂core
 ┃ ┣ 📂constants
 ┃ ┃ ┣ 📜app_constants.dart
 ┃ ┃ ┗ 📜colors.dart
 ┃ ┣ 📂services
 ┃ ┃ ┣ 📜ai_suggestion_service.dart
 ┃ ┃ ┣ 📜connectivity_service.dart
 ┃ ┃ ┣ 📜image_service.dart
 ┃ ┃ ┣ 📜local_storage_service.dart
 ┃ ┃ ┣ 📜location_service.dart
 ┃ ┃ ┣ 📜notification_service.dart
 ┃ ┃ ┗ 📜sync_service.dart
 ┃ ┗ 📂utils
 ┃ ┃ ┗ 📜validators.dart
 ┣ 📂models
 ┃ ┣ 📜local_models.dart
 ┃ ┣ 📜local_models.g.dart
 ┃ ┣ 📜report_model.dart
 ┃ ┗ 📜user_model.dart
 ┣ 📂providers
 ┃ ┣ 📜active_users_provider.dart
 ┃ ┣ 📜auth_provider.dart
 ┃ ┣ 📜reports_provider.dart
 ┃ ┣ 📜settings_provider.dart
 ┃ ┗ 📜user_provider.dart
 ┣ 📂screens
 ┃ ┣ 📂auth
 ┃ ┃ ┣ 📜login_screen.dart
 ┃ ┃ ┗ 📜register_screen.dart
 ┃ ┣ 📂home
 ┃ ┃ ┗ 📜home_screen.dart
 ┃ ┣ 📂problems
 ┃ ┃ ┗ 📜problem_type_screen.dart
 ┃ ┣ 📂reports
 ┃ ┃ ┣ 📜create_report_screen.dart
 ┃ ┃ ┣ 📜edit_report_screen.dart
 ┃ ┃ ┣ 📜my_reports_screen.dart
 ┃ ┃ ┗ 📜report_detail_screen.dart
 ┃ ┣ 📂security
 ┃ ┃ ┗ 📜security_home_screen.dart
 ┃ ┗ 📂settings
 ┃ ┃ ┗ 📜settings_screen.dart
 ┣ 📂widgets
 ┃ ┣ 📜ai_problem_suggestion_widget.dart
 ┃ ┣ 📜custom_button.dart
 ┃ ┣ 📜custom_drawer.dart
 ┃ ┣ 📜custom_text_field.dart
 ┃ ┣ 📜location_widget.dart
 ┃ ┣ 📜report_card.dart
 ┃ ┗ 📜sync_status_widget.dart
 ┗ 📜main.dart

```

# Arquitectura del sistema

El sistema utiliza una arquitectura basada en servicios cloud y componentes desacoplados.
```
Flutter App
     │
     │
Firebase SDK
     │
     ├── Firebase Authentication
     ├── Cloud Firestore
     ├── Firebase Storage
     │
Cloud Functions
     │
     └── Hugging Face API (IA)
```

# Sistema de notificaciones

El sistema utiliza **Firebase Cloud Messaging (FCM)** para enviar notificaciones cuando se crea un nuevo reporte.

Los usuarios pueden:

* recibir todas las notificaciones

* recibir solo categorías específicas

* desactivar notificaciones


# Sincronización offline

La aplicación permite registrar información incluso sin conexión.

Cuando el dispositivo pierde conexión:

los datos se guardan localmente, cuando vuelve la conexión, el sistema sincroniza automáticamente con Firestore.

# Pruebas del sistema

El sistema fue validado mediante pruebas de aceptación, evaluando:

* registro de usuarios

* validación de formularios

* autenticación

* creación de reportes

* detección de lenguaje ofensivo

* detección de duplicados

* sistema de notificaciones

Todos los casos de prueba obtuvieron resultados satisfactorios.

# Seguridad

El sistema implementa múltiples mecanismos de seguridad:

* autenticación segura con Firebase

* validación de datos en cliente

* reglas de seguridad en Firestore

* detección de lenguaje ofensivo mediante IA

* control de acceso por roles

# Instalación

**1️⃣ Clonar el repositorio**
```
git clone https://github.com/tu-usuario/tu-repositorio.git
```
**2️⃣ Instalar dependencias**

```
flutter pub get
```
**3️⃣ Configurar Firebase**

Agregar el archivo:
```
google-services.json
```
en:

```
android/app/
```
**4️⃣ Ejecutar la aplicación**
```
flutter run
```

# Autor

**Harold Joseph Sanchez Nogales**

Desarrollador Flutter

Proyecto académico enfocado en desarrollo Full Stack y sistemas inteligentes para gestión comunitaria.