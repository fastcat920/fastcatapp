#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void center_window_on_monitor(GtkWindow* window, int width, int height) {
  GdkDisplay* display = gdk_display_get_default();
  if (display == nullptr) return;

  GdkMonitor* monitor = nullptr;
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_window != nullptr) {
    monitor = gdk_display_get_monitor_at_window(display, gdk_window);
  }
  if (monitor == nullptr) {
    monitor = gdk_display_get_primary_monitor(display);
  }
  if (monitor == nullptr) {
    monitor = gdk_display_get_monitor(display, 0);
  }
  if (monitor == nullptr) return;

  GdkRectangle geometry;
  gdk_monitor_get_workarea(monitor, &geometry);
  int x = geometry.x + (geometry.width - width) / 2;
  int y = geometry.y + (geometry.height - height) / 2;
  if (x < geometry.x) x = geometry.x;
  if (y < geometry.y) y = geometry.y;
  gtk_window_move(window, x, y);
}

struct CenterWindowRequest {
  GtkWindow* window;
  int width;
  int height;
};

static gboolean center_window_later(gpointer user_data) {
  auto* request = static_cast<CenterWindowRequest*>(user_data);
  if (GTK_IS_WINDOW(request->window)) {
    center_window_on_monitor(request->window, request->width, request->height);
  }
  g_object_unref(request->window);
  delete request;
  return G_SOURCE_REMOVE;
}

static void schedule_center_window_on_monitor(
    GtkWindow* window,
    int width,
    int height,
    guint delay_ms) {
  g_object_ref(window);
  g_timeout_add(delay_ms, center_window_later,
                new CenterWindowRequest{window, width, height});
}

static gboolean on_main_window_map(GtkWidget* widget,
                                   GdkEvent*,
                                   gpointer) {
  auto* window = GTK_WINDOW(widget);
  center_window_on_monitor(window, 800, 600);
  schedule_center_window_on_monitor(window, 800, 600, 80);
  schedule_center_window_on_monitor(window, 800, 600, 240);
  return FALSE;
}

typedef struct {
  GtkFixed parent_instance;
  GtkWidget* flutter_view;
} FastcatOverlay;

typedef struct {
  GtkFixedClass parent_class;
} FastcatOverlayClass;

G_DEFINE_TYPE(FastcatOverlay, fastcat_overlay, GTK_TYPE_FIXED)

static void fastcat_overlay_size_allocate(GtkWidget* widget,
                                          GtkAllocation* allocation) {
  auto* overlay = reinterpret_cast<FastcatOverlay*>(widget);
  if (overlay->flutter_view != nullptr) {
    gtk_widget_set_size_request(overlay->flutter_view, allocation->width,
                                allocation->height);
    gtk_fixed_move(GTK_FIXED(widget), overlay->flutter_view, 0, 0);
  }
  GTK_WIDGET_CLASS(fastcat_overlay_parent_class)->size_allocate(widget,
                                                                allocation);
}

static void fastcat_overlay_get_preferred_width(GtkWidget*, gint* minimum,
                                                gint* natural) {
  *minimum = 0;
  *natural = 0;
}

static void fastcat_overlay_get_preferred_height(GtkWidget*, gint* minimum,
                                                 gint* natural) {
  *minimum = 0;
  *natural = 0;
}

static void fastcat_overlay_class_init(FastcatOverlayClass* klass) {
  auto* widget_class = GTK_WIDGET_CLASS(klass);
  widget_class->size_allocate = fastcat_overlay_size_allocate;
  widget_class->get_preferred_width = fastcat_overlay_get_preferred_width;
  widget_class->get_preferred_height = fastcat_overlay_get_preferred_height;
}

static void fastcat_overlay_init(FastcatOverlay* overlay) {
  overlay->flutter_view = nullptr;
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->window != nullptr) {
    gtk_window_present(self->window);
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;
  g_object_add_weak_pointer(G_OBJECT(window),
                            reinterpret_cast<gpointer*>(&self->window));
  gtk_window_set_icon_name(window, "FastCat");

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "快猫");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "快猫");
  }

  gtk_window_set_default_size(window, 800, 600);
  gtk_window_set_position(window, GTK_WIN_POS_CENTER);
  g_signal_connect(G_OBJECT(window), "map-event",
                   G_CALLBACK(on_main_window_map), nullptr);
  gtk_widget_show(GTK_WIDGET(window));
  center_window_on_monitor(window, 800, 600);
  schedule_center_window_on_monitor(window, 800, 600, 80);
  schedule_center_window_on_monitor(window, 800, 600, 240);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GtkWidget* flutter_container =
      GTK_WIDGET(g_object_new(fastcat_overlay_get_type(), nullptr));
  reinterpret_cast<FastcatOverlay*>(flutter_container)->flutter_view =
      GTK_WIDGET(view);
  gtk_widget_set_hexpand(flutter_container, TRUE);
  gtk_widget_set_vexpand(flutter_container, TRUE);
  gtk_container_add(GTK_CONTAINER(window), flutter_container);
  gtk_fixed_put(GTK_FIXED(flutter_container), GTK_WIDGET(view), 0, 0);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_widget_show(flutter_container);

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  if (self->window != nullptr) {
    g_object_remove_weak_pointer(G_OBJECT(self->window),
                                 reinterpret_cast<gpointer*>(&self->window));
    self->window = nullptr;
  }
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->window = nullptr;
}

MyApplication* my_application_new() {
  g_set_application_name("快猫");

  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     nullptr));
}
