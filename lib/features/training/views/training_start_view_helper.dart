
  void _startContinuousRun() async {
    // 1. Resetear y Configurar VM para modo continuo
    // Si hay series previas, preguntamos si borrar? 
    // Por simplicidad, asumimos que Quick Start es limpio.
    if (_vm.series.isNotEmpty) {
       bool confirm = await showDialog(
         context: context, 
         builder: (_) => AlertDialog(
           title: const Text("Iniciar nueva sesión"),
           content: const Text("Al iniciar una carrera continua se perderán las series actuales. ¿Continuar?"),
           actions: [
             TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text("Cancelar")),
             TextButton(onPressed: ()=>Navigator.pop(context, true), child: const Text("Continuar")),
           ],
         )
       ) ?? false;
       if (!confirm) return;
    }

    _vm.clearSeries();
    _vm.startContinuousSession();
    
    // 2. Navegar a TrainingSessionView
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(
       builder: (_) => TrainingSessionView(
         gpsActivo: true, // Carrera continua SIEMPRE usa GPS por defecto
       )
      )
    );

    // 3. Procesar resultado (Serie)
    if (result != null && result is Serie) {
       setState(() {
          // Extraer puntos
          if (result.gpsPoints != null) {
              _collectedGpsPoints = result.gpsPoints!.map((m) => GpsPoint.fromMap(m)).toList();
          }
           // Añadir serie única
          _vm.addSerie(result);
       });
       
       // 4. Iniciar flujo de guardado automático
       if (mounted) {
         _onFinishTrainingTap(); 
       }
    }
  }

  Widget _buildQuickStartTab() {
     return Padding(
       padding: const EdgeInsets.all(24.0),
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           const Icon(Icons.directions_run_rounded, size: 80, color: Tema.brandPurple),
           const SizedBox(height: 24),
           const Text(
             "Carrera Continua",
             style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
           ),
           const SizedBox(height: 12),
           Text(
             "Registra tu carrera libremente con GPS. \nSin series ni pausas programadas.",
             textAlign: TextAlign.center,
             style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
           ),
           const Spacer(),
           SizedBox(
             width: double.infinity,
             height: 60,
             child: ElevatedButton.icon(
               style: ElevatedButton.styleFrom(
                 backgroundColor: Tema.brandPurple,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                 elevation: 8,
                 shadowColor: Tema.brandPurple.withOpacity(0.5),
               ),
               icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
               label: const Text("EMPEZAR AHORA", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
               onPressed: _startContinuousRun,
             ),
           ),
           const SizedBox(height: 40),
         ]
       ),
     );
  }

  Widget _buildTemplatesTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20.0),
          
          if (_vm.source != null) ...[
             _buildTemplateCard(),
             const SizedBox(height: 16),
          ],
          
          _buildFormContainer(),
             
          const SizedBox(height: 24.0),
          
          if (_vm.source == null) ...[
            _buildAlarmSection(),
            const SizedBox(height: 20.0), 
          ],

          if (_vm.series.isEmpty) ...[
            _buildGpsToggle(),
            const SizedBox(height: 30.0),
          ],
          const Text(
            'Series Guardadas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Container(
            height: 1.0,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildSeriesList(),
            ),
          ),
        ],
      ),
    );
  }
