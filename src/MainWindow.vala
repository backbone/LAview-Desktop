namespace LAview.Desktop {

	using Gtk, LAview, Core;

	/**
	 * Main LAview Desktop window.
	 */
	public class MainWindow {

		ApplicationWindow window;
		PreferencesDialog pref_dialog;
		AboutDialogWindow about_dialog;
		SubprocessDialog subprocess_dialog;
		Gtk.Statusbar statusbar;
		Gtk.ListStore liststore_templates;
		Gtk.ListStore liststore_doc_objects;
		TreeView treeview_templates;
		TreeView treeview_objects;

		public MainWindow (Gtk.Application application) throws Error {
			var builder = new Builder ();
			builder.add_from_file (AppDirs.ui_dir + "/laview-desktop.glade");
			builder.connect_signals (this);

			window = builder.get_object ("main_window") as ApplicationWindow;
			statusbar = builder.get_object ("statusbar") as Statusbar;
			liststore_templates = builder.get_object ("liststore_templates") as Gtk.ListStore;
			liststore_doc_objects = builder.get_object ("liststore_objects") as Gtk.ListStore;
			treeview_templates = builder.get_object ("treeview_templates") as TreeView;
			treeview_objects = builder.get_object ("treeview_objects") as TreeView;
			window.title = _("LAview Desktop")
			        + @" $(Config.VERSION_MAJOR).$(Config.VERSION_MINOR).$(Config.VERSION_PATCH)";

			/* actions */
			var new_action = new SimpleAction ("new", null);
			new_action.activate.connect (new_callback);
			application.add_action (new_action);
			var open_action = new SimpleAction ("open", null);
			open_action.activate.connect (open_callback);
			application.add_action (open_action);
			var edit_action = new SimpleAction ("edit", null);
			edit_action.activate.connect (edit_callback);
			application.add_action (edit_action);
			var delete_action = new SimpleAction ("delete", null);
			delete_action.activate.connect (delete_callback);
			application.add_action (delete_action);
			var compose_action = new SimpleAction ("compose", null);
			compose_action.activate.connect (compose_callback);
			application.add_action (compose_action);
			var print_action = new SimpleAction ("print", null);
			print_action.activate.connect (print_callback);
			application.add_action (print_action);
			var edit_result_action = new SimpleAction ("edit_result", null);
			edit_result_action.activate.connect (edit_result_callback);
			application.add_action (edit_result_action);
			var saveas_action = new SimpleAction ("saveas", null);
			saveas_action.activate.connect (saveas_callback);
			application.add_action (saveas_action);
			var quit_action = new SimpleAction ("quit", null);
			quit_action.activate.connect (quit_callback);
			application.add_action (quit_action);
			var ref_action = new SimpleAction ("ref", null);
			ref_action.activate.connect (ref_callback);
			application.add_action (ref_action);
			var preferences_action = new SimpleAction ("preferences", null);
			preferences_action.activate.connect (preferences_callback);
			application.add_action (preferences_action);


			pref_dialog = new PreferencesDialog (application, window);
			subprocess_dialog = new SubprocessDialog (application, window);
			about_dialog = new AboutDialogWindow (application, window);

			#if (WINDOWS)
				check_paths ();
			#endif

			fill_liststore_templates ();

			application.app_menu = builder.get_object ("menubar") as MenuModel;
			application.menubar = builder.get_object ("main_toolbar") as MenuModel;
			window.application = application;

			window.destroy.connect (() => { window.application.quit (); });
		}

		void fill_liststore_templates () {
			var templates = AppCore.core.get_templates_readable_names ();

			// #124 if core doesn't contain any templates then try adding an example template
			var ex_templ_path = Path.build_path (Path.DIR_SEPARATOR_S, AppDirs.common_dir.get_path(),
			                                     "share/laview-core-0/templates/example.lyx");
			if (0 == templates.length && File.new_for_path(ex_templ_path).query_exists()) {
				AppCore.core.add_template (ex_templ_path);
				templates = AppCore.core.get_templates_readable_names ();
			}


			liststore_templates.clear();
			Gtk.TreeIter iter = Gtk.TreeIter();
			foreach (var t in templates) {
				liststore_templates.append (out iter);
				liststore_templates.set (iter, 0, t);
			}
		}

		void statusbar_show (string str) {
			var context_id = statusbar.get_context_id ("common_context");
			statusbar.push (context_id, str);
		}

		public void show_all () {
			window.show_all ();
			statusbar_show (_("We're ready, Commander! Select or create a template. :-)"));
		}

		[CCode (instance_pos = -1)]
		public void menu_about_activate (Gtk.ImageMenuItem item) {
			about_dialog.show_all ();
		}

		void new_callback (SimpleAction action, Variant? parameter) {
			string[] argv = { AppCore.core.lyx_path, "--execute", "buffer-new" };
			try {
				var subprocess = new SubprocessLauncher(  SubprocessFlags.STDIN_PIPE
					                                    | SubprocessFlags.STDOUT_PIPE
					                                    | SubprocessFlags.STDERR_PIPE);
				subprocess.spawnv(argv);
			} catch (Error err) {
				var msg = new MessageDialog (window, DialogFlags.MODAL, MessageType.ERROR,
				                             ButtonsType.CLOSE, _("Error: ")+err.message);
				msg.response.connect ((response_id) => { msg.destroy (); } );
				msg.show ();
			}
		}

		void open_callback (SimpleAction action, Variant? parameter) {
			FileChooserDialog chooser = new Gtk.FileChooserDialog (_("Select templates"), window,
			                                FileChooserAction.OPEN,
			                                _("_Cancel"), ResponseType.CANCEL,
			                                _("_Open"), ResponseType.ACCEPT);
			chooser.select_multiple = true;
			chooser.filter = new FileFilter ();
			chooser.filter.add_mime_type ("application/x-tex");
			chooser.filter.add_mime_type ("application/x-latex");
			chooser.filter.add_mime_type ("application/x-lyx");
			chooser.filter.add_pattern ("*.tex");
			chooser.filter.add_pattern ("*.latex");
			chooser.filter.add_pattern ("*.lyx");

			if (chooser.run () == ResponseType.ACCEPT) {
				var paths = chooser.get_filenames ();

				foreach (unowned string path in paths)
					AppCore.core.add_template (path);

				fill_liststore_templates ();
			}

			chooser.close ();
		}

		void edit_lyx_files (string[] paths) {
			string[] args = { AppCore.core.lyx_path, "--remote" };
			foreach (var p in paths) args += p;
			try {
				var subprocess = new SubprocessLauncher(  SubprocessFlags.STDIN_PIPE
					                                    | SubprocessFlags.STDOUT_PIPE
					                                    | SubprocessFlags.STDERR_PIPE);
				subprocess.spawnv(args);
			} catch (Error err) {
				var msg = new MessageDialog (window, DialogFlags.MODAL, MessageType.ERROR,
				                             ButtonsType.CLOSE, _("Error: ")+err.message);
				msg.response.connect ((response_id) => { msg.destroy (); } );
				msg.show ();
			}
		}

		int[] get_template_indices () {
			var selection = treeview_templates.get_selection ();
			var selected_rows = selection.get_selected_rows (null);
			int[] indices = {};
			foreach (var r in selected_rows) {
				indices += r.get_indices()[0];
			}
			return indices;
		}

		void edit_callback (SimpleAction action, Variant? parameter) {
			edit_selected_templates ();
		}

		void delete_callback (SimpleAction action, Variant? parameter) {
			var indices = get_template_indices ();
			for (int i = indices.length; i > 0; )
				AppCore.core.remove_template (indices[--i]);
			fill_liststore_templates ();
		}

		int[] get_objects_indices () {
			var selection = treeview_objects.get_selection ();
			var selected_rows = selection.get_selected_rows (null);
			int[] indices = {};
			foreach (var r in selected_rows) {
				indices += r.get_indices()[0];
			}
			return indices;
		}

		void compose_object () {
			try {
				var o_indices = get_objects_indices ();
				if (get_template_indices().length != 0 && o_indices.length != 0) {
					AppCore.core.compose_object (window, o_indices[0]);
					fill_objects_list ();

					TreeIter iter;
					if (treeview_objects.model.get_iter_first(out iter)) {
						for (var i = 0; i < o_indices[0]; ++i)
							treeview_objects.model.iter_next (ref iter);
						treeview_objects.get_selection ().select_iter (iter);
					}

					statusbar_show (_("After composing all objects print the document."));
				} else {
					statusbar_show (_("Select an object first."));
				}
			} catch (Error err) {
				var msg = new MessageDialog (window, DialogFlags.MODAL, MessageType.ERROR,
				                             ButtonsType.CLOSE, _("Error: ")+err.message);
				msg.response.connect ((response_id) => { msg.destroy (); } );
				msg.show ();
			}
		}

		void compose_callback (SimpleAction action, Variant? parameter) {
			compose_object();
		}

		[CCode (instance_pos = -1)]
		public void objects_activated (Gtk.TreeView treeview,
		                               Gtk.TreePath path,
		                               Gtk.TreeViewColumn column) {
			compose_object();
		}

		void edit_result_callback (SimpleAction action, Variant? parameter) {
			try {
				if (get_template_indices().length != 0) {
					var lyx_path = AppCore.core.get_lyx_file_path ();
					edit_lyx_files ({ lyx_path });
				}
			} catch (Error err) {
				var msg = new MessageDialog (window, DialogFlags.MODAL, MessageType.ERROR,
				                             ButtonsType.CLOSE, _("Error: ")+err.message);
				msg.response.connect ((response_id) => { msg.destroy (); } );
				msg.show ();
			}
		}

		void post_print () {
			try {
				Utils.open_document (AppCore.core.get_pdf_file_path (), window);
			} catch (Error err) {
				var msg = new MessageDialog (window, DialogFlags.MODAL, MessageType.ERROR,
				                             ButtonsType.CLOSE, _("Error: ")+err.message);
				msg.response.connect ((response_id) => { msg.destroy (); } );
				msg.show ();
			}
		}

		void print_callback (SimpleAction action, Variant? parameter) {
			if (get_template_indices().length != 0) {
				try {
					subprocess_dialog.show_all (AppCore.core.print_document (),
					                            _("=== Print to PDF file... ===\n"),
					                            post_print);
				} catch (Error err) {
					var msg = new MessageDialog (window, DialogFlags.MODAL, MessageType.ERROR,
					                             ButtonsType.CLOSE, _("Error: ")+err.message);
					msg.response.connect ((response_id) => { msg.destroy (); } );
					msg.show ();
				}
			}
		}

		void preferences_callback (SimpleAction action, Variant? parameter) {
			pref_dialog.show_all ();
		}

		void ref_callback (SimpleAction action, Variant? parameter) {
			try {
				show_uri (null, "https://redmine.backbone.ws/projects/laview/wiki", Gdk.CURRENT_TIME);
			} catch (Error err) {
				var msg = new MessageDialog (window, DialogFlags.MODAL, MessageType.ERROR,
				                             ButtonsType.CLOSE, _("Error: ")+err.message);
				msg.response.connect ((response_id) => { msg.destroy (); } );
				msg.show ();
			}
		}

		void edit_selected_templates () {
			var indices = get_template_indices ();
			if (indices.length != 0) {
				string[] paths = {};
				foreach (var i in indices) {
					paths += AppCore.core.get_template_path_by_index (i);
				}
				edit_lyx_files (paths);
			}
		}

		[CCode (instance_pos = -1)]
		public void templates_row_activated (Gtk.TreeView treeview,
		                                     Gtk.TreePath path,
		                                     Gtk.TreeViewColumn column) {
			edit_selected_templates ();
		}

		void fill_objects_list () throws Error {
			liststore_doc_objects.clear();
			var indices = get_template_indices ();
			if (indices.length != 0) {
				var doc_objects = AppCore.core.get_objects_list (indices[0]);
				Gtk.TreeIter iter = Gtk.TreeIter();
				foreach (var t in doc_objects) {
					liststore_doc_objects.append (out iter);
					liststore_doc_objects.set (iter, 0, t);
				}
			}
		}

		[CCode (instance_pos = -1)]
		public void templates_cursor_changed (Gtk.TreeView treeview) {
			try {
				fill_objects_list ();
			} catch (Error err) {
				var msg = new MessageDialog (window, DialogFlags.MODAL, MessageType.ERROR,
				                             ButtonsType.CLOSE, _("Error: ")+err.message);
				msg.response.connect ((response_id) => { msg.destroy (); } );
				msg.show ();
				return;
			}

			statusbar_show (_("Document analized, select an object and set it's properties."));
		}

		[CCode (instance_pos = -1)]
		public void objects_cursor_changed (Gtk.TreeView treeview) {
			statusbar_show (_("Press 'Properties' button to compose the object."));
		}

		void saveas_callback (SimpleAction action, Variant? parameter) {
			var indices = get_template_indices ();
			if (indices.length == 0) return;
			string tmp_pdf = "";
			try {
				tmp_pdf = AppCore.core.get_pdf_file_path ();
			} catch (Error err) {
				statusbar_show (_("Prepare the document first! >;-]"));
				return;
			}

			FileChooserDialog chooser = new Gtk.FileChooserDialog (_("Select destination"), window,
			                                FileChooserAction.SAVE,
			                                _("_Cancel"), ResponseType.CANCEL,
			                                _("_Save"), ResponseType.ACCEPT);
			chooser.select_multiple = false;
			chooser.filter = new FileFilter ();
			chooser.filter.add_mime_type ("application/pdf");
			chooser.filter.add_pattern ("*.pdf");

			// set folder
			if (AppCore.settings.pdf_save_path != "")
				chooser.set_current_folder (AppCore.settings.pdf_save_path);

			// set current pdf file name or select an existance one
			var template_name = AppCore.core.get_template_path_by_index (indices[0]);
			template_name = File.new_for_path(template_name).get_basename ();
			if (   template_name.down().has_suffix(".lyx")
			    || template_name.down().has_suffix(".tex")
			) {
				var date = Time.local (time_t()).format("-%Y.%m.%d_%H-%M-%S");
				template_name = template_name.splice (template_name.length-4, template_name.length, date+".pdf");
			}
			if (File.new_for_path(template_name).query_exists())
				chooser.set_filename (template_name);
			else
				chooser.set_current_name (template_name);

			// open dialog
			var response = chooser.run ();

			// process response
			if (response == ResponseType.ACCEPT) {
				try {
					File.new_for_path (tmp_pdf).copy (chooser.get_file(), FileCopyFlags.OVERWRITE, null,
					           (current_num_bytes, total_num_bytes) => {
									statusbar_show (@"$current_num_bytes "+_("bytes of")+
					                                @" $total_num_bytes "+_("bytes copied/saved")+".");
					           });
					AppCore.settings.pdf_save_path = chooser.get_file().get_parent().get_path();
					statusbar_show (_("Save/Copy operation complete! :-)"));
				} catch (Error err) {
					var msg = new MessageDialog (chooser, DialogFlags.MODAL, MessageType.ERROR,
					                             ButtonsType.CLOSE, _("Error: ")+err.message);
					msg.response.connect ((response_id) => { msg.destroy (); chooser.close (); } );
					msg.show ();
				}
			}

			chooser.close ();
		}

		void quit_callback (SimpleAction action, Variant? parameter) {
			window.destroy();
		}

		#if (WINDOWS)
		void check_paths () {
			bool all_paths_exist = true;
			string[] paths1 = {AppCore.core.lyx_path, AppCore.core.latexmk_pl_path, AppCore.core.perl_path};
			foreach (var path in paths1) {
				if (!File.new_for_path(path).query_exists())
					all_paths_exist = false;
			}
			if (!all_paths_exist) pref_dialog.show_all ();
		}
		#endif
	}
}
