# NightShift — Documentación técnica

> *Lock the screen. Keep the work going.*

**Versión:** 1.0.0 · **Plataforma:** macOS 13+ (Ventura) · **Arquitectura:** arm64 (Apple Silicon) · **Autor:** Diego Bogotá Linares — [diegobogota.com](https://diegobogota.com)

---

## 1. Resumen

NightShift es una **app de barra de menús** (menu bar app) para macOS que **impide el reposo del sistema por inactividad** durante un tiempo elegido por el usuario (1, 2, 3 o 4 horas).

**El problema que resuelve:** el Wi-Fi "se cae" tras unos minutos de inactividad. La causa real no es el router: el Mac entra en *Idle Sleep* a los 15 minutos (`pmset sleep 15`) y, al dormir, apaga la interfaz Wi-Fi (`networkoversleep 0`). Esto queda registrado en el log del sistema:

```
Entering Sleep state due to 'Idle Sleep' ... Using Batt
```

**La solución:** mantener el sistema despierto con la API oficial de energía de macOS, sin cambiar ninguna configuración del equipo.

---

## 2. Qué hace, concretamente

| Función | Detalle |
|---|---|
| ⏱️ Evita el reposo por inactividad | Mientras está activa, el Mac **no entra en reposo** aunque no haya interacción del usuario (1–4 h, a elección). |
| 🟢 Mantiene el Wi-Fi conectado | Consecuencia directa de lo anterior: como el sistema no duerme, la interfaz Wi-Fi no se apaga. |
| 🔒 Respeta el bloqueo de pantalla | La pantalla **sí se apaga** por inactividad y **sí se bloquea** según la política vigente. NightShift no interfiere en nada de eso. |
| 🌙 Icono con cuenta regresiva | El icono de la barra de menús muestra el tiempo restante en formato `🌙 3:59:59`, actualizado cada segundo. |
| ✅ Auto-apagado | Al vencer el tiempo elegido, la aserción se libera sola y el sistema vuelve a su comportamiento normal (reposo a los 15 min de inactividad). |
| 🔋 Sin fricción de permisos | No pide contraseña de administrador, no pide permisos de Accesibilidad ni de Notificaciones. |

### El menú de la barra de menús

```
🌙  NightShift          ← título (no clicable)
─────────────
  1 hora
  2 horas               ← al elegir una, aparece ✓ junto a la activa
  3 horas
  4 horas
─────────────
  Desactivar   (⌘D)     ← libera la aserción al instante
─────────────
  Salir        (⌘Q)
```

- **Estados del icono:** `🌙` (inactiva) → `🌙 3:59:59` (activa, cuenta regresiva) → `🌙` (al vencer o desactivar).
- El ítem **Desactivar** solo está habilitado cuando hay una sesión activa.

---

## 3. Cómo funciona (mecanismo técnico)

### La API: `IOPMAssertion`

NightShift usa el mismo mecanismo oficial que usa el comando `caffeinate` de Apple: las **power assertions** de IOKit.

```swift
IOPMAssertionCreateWithName(
    kIOPMAssertionTypePreventUserIdleSystemSleep,  // tipo de aserción
    IOPMAssertionLevel(kIOPMAssertionLevelOn),     // nivel: ON
    "NightShift",                                  // nombre (visible en pmset)
    &assertionID                                   // ID devuelto por el sistema
)
```

Qué hace el sistema con esa llamada:

1. El daemon `powerd` registra una aserción **"PreventUserIdleSystemSleep"** a nombre del proceso NightShift.
2. Mientras la aserción exista, el temporizador de inactividad del sistema **no acumula tiempo hacia el reposo** (el contador de idle se reinicia de forma virtual, sin simular input).
3. Al liberarla (`IOPMAssertionRelease`), el sistema vuelve a su temporizador normal.

### Flujo de la app

```
Usuario elige "2 horas"
        │
        ▼
IOPMAssertionCreateWithName(PreventUserIdleSystemSleep)
        │
        ▼
deadline = ahora + 2h ──► Timer cada 1 s ──► refresca icono (cuenta regresiva)
        │                                        │
        │                                        ▼
        │                          ¿Date() >= deadline? ──sí──► IOPMAssertionRelease()
        │                                        │                            │
        ◄────────── clic en "Desactivar" ────────┘                            ▼
                                                              sistema vuelve a dormir a los 15 min
```

### Componentes del código (`Sources/main.swift`)

| Componente | Responsabilidad |
|---|---|
| `PowerState` | Estado de energía: crea/libera la aserción, guarda `deadline` y las horas activas, administra el `Timer` de 1 s. |
| `AppDelegate` | Crea el `NSStatusItem` (icono 🌙), construye el menú, maneja las acciones y refresca el título del icono y los checks del menú. |
| `app.setActivationPolicy(.accessory)` | App sin icono en el Dock (comportamiento de utilidad de barra de menús). Complementado con `LSUIElement=true` en el `Info.plist`. |

---

## 4. Qué NO hace (por diseño)

Estas omisiones son intencionales y son la razón por la que la app es compatible con entornos corporativos:

- ❌ **No modifica `pmset`** — no toca `sleep`, `networkoversleep` ni ningún ajuste de energía del sistema.
- ❌ **No simula mouse ni teclado** — no escribe en apps abiertas ni reinicia contadores de seguridad corporativos.
- ❌ **No evita el reposo con pantalla abierta** (`PreventUserIdleDisplaySleep` no se usa) — la pantalla se apaga normalmente.
- ❌ **No desactiva el bloqueo de pantalla** — se respeta el perfil de seguridad (Intune/CIS).
- ❌ **No requiere permisos de administrador** — se instala en `~/Applications`, sin `/Applications` ni `sudo`.
- ❌ **No corre en segundo plano al reiniciar** — solo actúa mientras está abierta y con una duración activa.

> **Nota de cumplimiento:** la política corporativa (perfil Intune CIS `os_sleep_and_display_sleep_apple_silicon_enable`) exige reposo ≤ 15 min. NightShift **no modifica esa configuración**: solo añade una aserción temporal de proceso, la misma que genera cualquier app que use `caffeinate` o reproducción de video. Al cerrar la app (o vencer el tiempo), el equipo vuelve a dormir exactamente igual que antes.

---

## 5. Cómo verificar que está funcionando

Con la app activa (alguna duración elegida):

```bash
# 1. La aserción debe aparecer a nombre de NightShift
pmset -g assertions | grep -i nightshift

# 2. Ver la aserción con detalle (tiempo restante, tipo)
pmset -g assertions

# 3. Confirmar que el proceso está vivo
pgrep -l NightShift

# 4. (Verificación extendida) tras 30+ min de inactividad:
pmset -g log | grep "Idle Sleep"    # NO debe aparecer ninguna entrada nueva
```

Salida esperada en `pmset -g assertions` mientras está activa:

```
   PreventUserIdleSystemSleep     1
   pid 123(NightShift): [...] PreventUserIdleSystemSleep named: "NightShift"
```

---

## 6. Instalación y compilación

### Desde una Release (recomendado)

1. Descarga `NightShift-macOS-arm64.zip` desde [Releases](https://github.com/diegobogota/NightShift/releases/latest).
2. Descomprime y mueve `NightShift.app` a `~/Applications`.
3. Clic derecho → **Abrir** (primera vez, para pasar Gatekeeper).
4. Si aparece aviso de cuarentena:
   ```bash
   xattr -d com.apple.quarantine ~/Applications/NightShift.app
   ```

### Compilar desde el código

Requisitos: macOS 13+, Command Line Tools de Xcode (`xcode-select --install` si faltan).

```bash
git clone https://github.com/diegobogota/NightShift.git
cd NightShift
./build.sh --install    # compila, firma ad hoc y copia a ~/Applications
```

---

## 7. Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| "App dañada, no se puede abrir" | Cuarentena de Gatekeeper | `xattr -d com.apple.quarantine ~/Applications/NightShift.app` |
| El icono 🌙 no aparece en la barra | macOS oculta ítems poco usados | Mantén ⌘ y arrastra el icono a la zona visible |
| El Wi-Fi se cae igual | La app no tiene duración activa (solo está abierta) | Elige 1–4 h en el menú; verifica con `pmset -g assertions` |
| No aparece en "Apps abiertas" al reiniciar | Es una app de barra de menús (`LSUIElement`) | Es normal; ábrela manualmente o agrégala a "Ítems de inicio" |
| La cuenta regresiva no avanza | El Timer se pausó (App Nap) | Reabre la app; el mecanismo de aserción sigue activo aunque el Timer se pause |

---

## 8. Arquitectura del bundle

```
NightShift.app/
└── Contents/
    ├── Info.plist              ← LSUIElement, CFBundleIconFile=AppIcon, min macOS 13
    ├── MacOS/
    │   └── NightShift          ← binario Swift (arm64, enlazado con AppKit + IOKit)
    ├── Resources/
    │   └── AppIcon.icns        ← icono (16→1024 px, variantes @2x)
    └── _CodeSignature/         ← firma ad hoc (codesign -s -)
```

**Dependencias externas:** ninguna. Todo lo que usa la app (AppKit, IOKit) viene incluido en macOS.
