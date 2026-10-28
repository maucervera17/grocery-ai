# Integración iOS

Proyecto existente importado de `feat/ios`, commit
`9243aa01a80a80542c2bfa7f9cb3bbe6bc8479ba`. No es una segunda app.

Abrir `GroceryAI.xcodeproj` en Xcode con SDK iOS 26 / compilador Swift 6.2 o posterior.
`SWIFT_VERSION=6.0` es el modo de lenguaje Swift 6; no selecciona la versión instalada del compilador.
Elegir un simulador iOS 26 y ejecutar. El proyecto no necesita firma para simulador.

`Data/API/GroceryAPIClient.swift` contiene la única URL base configurable.
Por defecto conecta `http://127.0.0.1:3000`; primero iniciar el backend desde la raíz.
En un iPhone físico hace falta URL accesible por red y configurar permiso de red
local/ATS para ese entorno; no se habilita acceso HTTP arbitrario de producción.

Cambios de integración:
- Servicios HTTP reales por defecto; mocks solo para previews/pruebas.
- Un POST con dos acciones; notes:null se serializa explícitamente.
- Timeout de red 30 s, validación de respuesta y cantidades, manejo de error sin perder borrador.
- Mapeo de JSON snake_case a modelos existentes, precios, fechas y fuentes.
- Advertencias de respuestas parciales visibles; solo se guarda una comparación completa.
- Historial inicial vacío; no se inventan compras previas.
- Cambiar borrador invalida el resultado anterior.
- Localización When In Use, reverse geocoding a CP mexicano, timeout 20 s y entrada manual.
  Solo se transmite CP; no se envían coordenadas.

La app integrada **compila en GitHub Actions**, run 40621570223, con destino genérico
iOS Simulator y sin firma. No hay Xcode local y todavía no se probó la interacción
en un simulador/dispositivo. También se validaron sintaxis Swift y formato del proyecto.
El SDK macOS de CommandLineTools también falla al importar CoreFoundation en este
entorno, por lo que no se declara validación de tipos Swift.

Prueba de aceptación:
1. Enviar «Agrega 2 litros de leche, 12 huevos y 1 kg de arroz».
2. Editar y conservar las cantidades, comparar con CP 06700.
3. Ver dos tiendas, total demo $134, fuentes/fechas y aviso demo.
4. Guardar, repetir desde historial y comprobar que el pedido anterior permanece igual.
5. Probar CP manual y permiso de ubicación denegado.
6. Detener backend para verificar error y recuperación; probar Dynamic Type,
   VoiceOver y ambos temas antes de marcar terminado.
