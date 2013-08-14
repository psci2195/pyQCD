import numpy as np

def create(measurement_settings, lattice_settings,
						simulation_settings):
	"""Creates the variables needed to store the measurements"""

	num_configs = simulation_settings['timing_run']['num_configurations'] \
	  if simulation_settings['timing_run']['enabled'] \
	  else simulation_settings['num_configurations']

	measurement_keys = measurement_settings.keys()
	out = []
	
	for key in measurement_keys:
		if key == 'plaquette':
			plaquette_store = np.zeros(num_configs)
			out.append((key, plaquette_store))

		elif key == "wilson_loop":
			wilson_loop_store \
			  = np.zeros((num_configs,
						  measurement_settings[key]['r_max'] - 1,
						  measurement_settings[key]['t_max'] - 1))

			out.append((key, wilson_loop_store))

		elif key == "propagator":
			propagator_store \
			  = np.zeros((num_configs,
						  lattice_settings['L']**3 * lattice_settings['T'],
						  12, 12), dtype=complex)
			out.append((key, propagator_store))

	return dict(out)

def do(settings, interface, store, config):
	"""Loops through the settings and performs the measurements"""
	keys = settings.keys()

	for key in keys:
		if key == "plaquette":
			store[key][config] = interface.lattice.av_plaquette()
			print("Average plaquette = %f" % store[key][config])
		elif key == "wilson_loop":
			store[key][config] = interface.get_wilson_loops(settings[key])
		elif key == "propagator":
			store[key][config] = interface.get_propagator(settings[key])	

def save(settings, store):
	"""Loops through the stored measurements and writes them out to a file"""
	keys = settings.keys()

	for key in keys:
		np.save(settings[key]["filename"], store[key])
