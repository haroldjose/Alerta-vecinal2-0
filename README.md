# 🛡️ Proyecto: Alerta Vecinal

El presente proyecto consiste en el desarrollo de una aplicación movil Full Stack diseñada para fortalecer la seguridad comunitaria mediante la gestion inteligente de reportes. La solución utiliza una arquitectura basada en **Flutter** para el fronted y Firebase como núcleo del backend, permitiendo una sincronización en tiempo real y una alta escalabilidad. 

## Objetivo general

Desarrollar una aplicación móvil full stack durante la gestión 2026 que permita a los vecinos la organización de reportes vecinales, incorporando mejoras en seguridad y modelos de inteligencia artificial destinados a la moderación de lenguaje ofensivo y detección de reportes duplicados.

## Objetivos especificos

* Optimización de rendimiento Multimedia
  * Implementación de flujo de procesamiento que reduzca el peso de archivos multimedia en al menos un 30% mediante compresión automática en la nube, reflejado en la visualización fluida en la aplicación.
* Rediseñar la experiencia de usuario
  * Intefaz de usuario renovada que proporcione retroalimentación visual inmediata y mensajes de estado claros basados en la respuesta lógica del sistema ante cada acción del usuario.
* Mejorar la seguridad de la aplicación
  * Sistema de acceso que valide credenciales bajo politicas de complejidad en tiempo real y ejecute bloqueo temporal tras 5 intentos fallidos de inicio de sesión detectados por el sistema.
* Cambiar el sistema de notificaciones 
  * Modulo de alertas inteligentes que permita al usuario suscribirse a categorias especificas y recibir notificaciones push personalizados mediante la segmentación de topicos en tiempo real.
* Integrar módulos de inteligencia artificial
  * Flujo de creación de reportes automatizado que analice el contenido mediante APIs externas, bloqueando la publicación que contenga lenguaje ofensivo o que sean identificadas como duplicadas.          

### ¿Que hace el sistema?

* Los usuarios admin y vecino pueden crear reportes. 
* Los usuarios vecinos pueden editar su propios reportes y no pueden eliminar.
* El usuario admin edita el estado del reporte y puede eliminar los reportes.
* El formulario de reportes tienen los campos titulo, tipo del problema, estado, fecha, imagen, ubicación y descripción.
* La IA controlará si existe lenguaje ofensivo o no.
* La IA controlará duplicados en los reportes.
* Los reportes no se podrán guardar ni mostrar si  existe de lenguaje ofensivo o reportes duplicados.


## Tecnologias

* Flutter, dark, Riverpod
* Firebase auth, Firebase Storage, Firebase Cloud Messaging y Hive
* Google NLP, Perspective, OpenAI

## Entidades principales

### 👤 Entidad: Users
- `name`
- `role`
- `cargo`
- `email`
- `createdAt`
- `lastActive`

### 📄 Entidad: Reports
- `title`
- `userId`
- `userName`
- `status`
- `problemType`
- `imageUrl`
- `description`
- `createdAt`

## Flujo del sistema

1. El usuario inicia sesión
1. el backend verifica credenciales y devuelve confirmación si es válido o denegado.
1.  El usuario llena el formulario de reporte.
1. La IA analiza el lenguaje para detectar lenguaje ofensivo.
1. El usuario debe modificar el lenguaje para poder crear el reporte en caso de lenguaje ofensivo.
1. La IA verifica reportes existentes para ver duplicidad.
1. El usuario debe modificar su reporte para poder crear o cancelar la creación del reporte.

## Arquitectura 

```
App Flutter
    │
Firebase Auth  →  genera token JWT
    │
Firestore  ←→  Storage
    │
Cloud Functions (lógica segura)
```


## Endpoints core

```
createUserWithEmailAndPassword    // registra un nuevo usuario en Firebase Auth
signInWithEmailAndPassword      // inicia sesión verificando email y contraseña
signOut                       // cierra la sesión del usuario

collection('users').doc(uid).set()    // crea el documento del usuario en Firestore
collection('users').doc(uid).get()    // obtiene los datos del usuario desde Firestore


collection('reports').snapshots()     // escucha en tiempo real todos los reportes
collection('reports').where('userId')    // filtra reportes por usuario
collection('reports').where('problemType')  // filtra reportes por tipo de problema
collection('reports').doc(id).set()     // crea/guarda un reporte nuevo
collection('reports').doc(id).update()    // actualiza campos del reporte
collection('reports').doc(id).update({status}) // actualiza solo el estado del reporte
collection('reports').doc(id).delete()      // elimina el reporte


``` 

## Ejecutar el proyecto

1. Clona el proyecto 
1. instala dependencias dentro del proyecto ` flutter pub get`
1. verifica configuración de Firebase en ` android/app/google-services.json`
1. selecciona el dispositivo ` flutter devices`
1. ejecut el proyecto `flutter run`

## Variables de entorno 

```
{
  "project_info": {
    "project_number": "400213109312",
    "project_id": "",
    "storage_bucket": "alerta-vecinal-297eb.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "",
        "android_client_info": {
          "package_name": "com.example.alerta_vecinal"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": ""
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
```


