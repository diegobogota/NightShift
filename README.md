# NightShift 🌙

*Lock the screen. Keep the work going.*

🔒 Screen locked
🟢 Wi-Fi connected
🤖 Agents running
🌙 Human away

> **Estado:** ✅ Fase 1 completa. La app nativa está compilada en `build/NightShift.app` (usa la API oficial `IOPMAssertion`, no modifica `pmset` ni la política corporativa). Pendiente: verificación de Fase 2 (30 min de inactividad).

Pequeña app de barra de menú para macOS que evita que el sistema entre en reposo por inactividad durante 1–4 horas, manteniendo el Wi‑Fi conectado.

## Problema

El Wi‑Fi "se cae" tras un tiempo de inactividad. El diagnóstico mostró que **no es una desconexión del router**: el Mac entra en `Idle Sleep` a los 15 minutos (`pmset sleep 15`) y, al dormir, apaga el Wi‑Fi (`networkoversleep 0`).

```
Entering Sleep state due to 'Idle Sleep' ... Using Batt
```

La política de seguridad corporativa (perfil Intune CIS `os_sleep_and_display_sleep_apple_silicon_enable`) exige un reposo de 15 minutos o menos, por lo que no se cambia la configuración de `pmset`.

## Solución

Usar la API oficial de energía de macOS (`IOPMAssertion`) para **impedir el reposo del sistema** durante un tiempo definido.

- ✅ El Wi‑Fi sigue conectado.
- ✅ La pantalla se apaga y **se bloquea normalmente** (se respeta el bloqueo de pantalla).
- ✅ No requiere permisos de administrador ni de Accesibilidad.
- ❌ No simula mouse ni teclado (evita escribir en apps abiertas y no desactiva controles de seguridad).

## Plan

### Fase 0 — Versión rápida (sin compilar)

- Crear un `.app` con `osacompile` que pregunte "¿Cuántas horas? 1/2/3/4" y ejecute:

  ```bash
  caffeinate -i -t <segundos>   # 4h = 14400, 3h = 10800
  ```

- Sirve para validar que el Wi‑Fi ya no se cae.

### Fase 1 — App nativa en Swift

| Paso | Detalle |
|---|---|
| Requisito | Command Line Tools de Xcode (`xcode-select -p`). Si no están, su instalación puede requerir aprobación según la política de software. |
| UI | `MenuBarExtra` de SwiftUI (macOS 13+): icono ☕ con opciones 1h / 2h / 3h / 4h / Desactivar y tiempo restante. |
| Mecanismo | `IOPMAssertionCreateWithName` con `kIOPMAssertionTypePreventUserIdleSystemSleep`. |
| Temporizador | Al vencer el tiempo o al salir de la app se llama a `IOPMAssertionRelease`. |
| Batería (opcional) | Liberar la aserción automáticamente si la batería baja del 20 %. |
| Build | `main.swift` compilado con `swiftc`, empaquetado como `.app` con `Info.plist` (`LSUIElement=true`) y firmado ad hoc (`codesign -s -`). |
| Ubicación | `~/Applications/NightShift.app` (no requiere admin). |

### Fase 2 — Verificación

1. Activar 4h y ejecutar `pmset -g assertions`. Debe aparecer `PreventUserIdleSystemSleep` a nombre de NightShift.
2. Dejar el equipo inactivo unos 30 min. La pantalla debe bloquearse y `pmset -g log` no debe mostrar `Idle Sleep`.
3. Confirmar que el Wi‑Fi sigue conectado (`networksetup -getairportnetwork en0` o un `ping` en segundo plano).
4. Desactivar desde el menú y confirmar que la aserción desaparece.

## Uso rápido mientras tanto

```bash
caffeinate -i -t 14400 &   # mantener despierto 4 horas
pgrep caffeinate           # ver el PID
kill <PID>                 # cancelar antes de tiempo
```

## Descargar

Descarga la app compilada desde [Releases](https://github.com/diegobogota/NightShift/releases/latest): descarga `NightShift-macOS-arm64.zip`, descomprime, mueve `NightShift.app` a `~/Applications` y ábrela con clic derecho → **Abrir** (primera vez). Si aparece aviso de cuarentena: `xattr -d com.apple.quarantine ~/Applications/NightShift.app`.

## Autor

**Diego Bogotá Linares**
🌐 [diegobogota.com](https://diegobogota.com)
