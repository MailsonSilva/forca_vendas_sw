# Memory Context: Força de Vendas Application

This document logs the architecture, design choices, data flow, key dependencies, and synchronization mechanisms implemented in the **Força de Vendas** Flutter application.

---

## 1. Project Overview & Architecture

The application is structured following a layered architectural pattern (UI, Business Logic, and Data) to maintain a clean separation of concerns, enable background task synchronization, and optimize state management.

### Main Architecture Principles:
- **Presentation Layer (UI):** Modular Flutter widgets (`StatefulWidget`/`StatelessWidget`) designed with consistent 16px margins/paddings, 12px border radius, and structured forms utilizing global `InputDecorationTheme`.
- **State Management:** Handled via the `provider` package. Global app state resides in `AppState` (`lib/core/app_state.dart`). UI components watch/select from the AppState to trigger reactive rebuilds.
- **Data & Storage Layer:** Local storage powered by SQLite and `SharedPreferences`. The local database serves as the offline cache. XML is utilized for importing/exporting database load files.

---

## 2. Key Components & Custom Workflows

### A. Background Sync & Carga de Dados
- **Background Synchronization:** Implemented with `flutter_workmanager` to run DB and image synchronization tasks in separate OS isolates. This prevents background tasks from stopping when the application is minimized or sent to the background.
- **IPC Mechanism:** Since background isolates run on separate threads, `SharedPreferences` is used as an IPC bridge. The UI polls `SharedPreferences` dynamically (every 2 seconds) to display real-time download and upload progress.
- **Background Service:** Located at [background_sync_service.dart](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/services/background_sync_service.dart). Manages task registration, cancelation, and status updates.
- **Image Sync:** Replaces old isolate spawning with WorkManager HTTP manifest chunked download (`lib/action_code/sincronizar_imagens.dart` logic integrated into the service).
- **FTP Sync:** The database is downloaded and uploaded using `ftpconnect` in the background ([download_database_from_ftp.dart](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/action_code/download_database_from_ftp.dart)).

### B. Client Menu Improvements
- **DDD & Number Fields:** Visual representation of telephone inputs split into a standard DDD field (flex 2) and Number field (flex 5) side-by-side using `InputDecorator` and `Row`. The data is seamlessly combined and validated during saving (requires exactly 2 digits for DDD).
- **Aesthetic Consistency:** Card details use 12px border radius and 16px inner padding. Modals (like `modal_pedidos_widget.dart` and `modal_cliente_widget.dart`) standardized to use uniform background, title colors, icons, and typography.

### C. Product & Inventory Refactoring
- **Code & Price Display:** Bold representation of product code. Color-coded prices:
  - **Preço > 0:** Dynamic color `#2E7D32` (Green).
  - **Preço == 0:** Black text color.
- **Detail View:** Custom card layouts updated to use 16px padding instead of 24px, improving alignment and mobile viewport space efficiency.

### D. Order Entry Layout
- **Visual Forms:** Dropdown selections (Linha/Segmento and Plano de Pagamento) redesigned with `DropdownButtonFormField` integrated with global `InputDecorationTheme` to align with the application input field design.
- **Search Dialog:** Compact client selection layout using `InputDecorator` to search and display client references.

---

## 3. Tech Stack & Key Dependencies

| Dependency | Purpose | Configuration Notes |
|---|---|---|
| `flutter_workmanager` | OS background scheduler / execution | Native registrations configured in AndroidManifest.xml / Info.plist |
| `shared_preferences` | IPC and persistence layer | Used for UI polling status of background Isolates |
| `ftpconnect` | FTP file transfer for DB sync | Core database sync |
| `http` | HTTP download manifest and images | Used for image synchronization |
| `provider` | State Management | Declared in `main.dart` with `AppState` |
| `percent_indicator` | Progress tracking UI widgets | Used in `AtualizarCargaWidget` and `AtualizarImagensWidget` |

---

## 4. Maintenance & Next Steps

When adding new background capabilities or modifying data parsing workflows:
1. Always register new background tasks in the dispatcher in [background_sync_service.dart](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/services/background_sync_service.dart).
2. For any UI components in dialogs/bottom sheets, follow the standardized modal structure defined in [modal_pedidos_widget.dart](file:///d:/sistema/projetos/Mobile/forca_de_vendas/lib/components/modal_pedidos/modal_pedidos_widget.dart).
