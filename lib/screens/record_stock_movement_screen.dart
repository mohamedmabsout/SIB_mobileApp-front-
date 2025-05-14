import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:sib_expense_app/config/dio_client.dart';
import 'package:sib_expense_app/models/dropdown_item.dart';

// Define enum locally or import
enum MovementType { IN, OUT }

class RecordStockMovementScreen extends StatefulWidget {
  final String token;
  final int? initialEquipmentId; // Optionally pre-select equipment

  const RecordStockMovementScreen({
    Key? key,
    required this.token,
    this.initialEquipmentId
  }) : super(key: key);

  @override
  _RecordStockMovementScreenState createState() => _RecordStockMovementScreenState();
}

class _RecordStockMovementScreenState extends State<RecordStockMovementScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  // State
  DropdownItem? _selectedEquipment;
  MovementType? _selectedType;
  DateTime? _movementDate = DateTime.now(); // Default to today

  // Dropdown Data
  List<DropdownItem> _equipmentItems = [];

  bool _isLoading = false; // For submit button
  bool _isFetchingData = true;
  String? _errorMessage;
  final Dio _dio = createDioClient();
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _fetchEquipmentList();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchEquipmentList() async {
    if (!mounted) return;
    setState(() { _isFetchingData = true; _errorMessage = null; });
    try {
      // **MODIFY:** Use your actual endpoint for simplified equipment list (ID, Name)
      final response = await _dio.get('/api/equipment/list-simple'); // Needs backend endpoint
      if (!mounted) return;

      if (response.statusCode == 200 && response.data is List) {
        _equipmentItems = (response.data as List).map((eq) {
          return DropdownItem(id: eq['id'] as int? ?? 0, name: eq['name'] ?? 'Unknown');
        }).toList();

        // Pre-select if initial ID was passed
        if (widget.initialEquipmentId != null) {
          try {
            _selectedEquipment = _equipmentItems.firstWhere((item) => item.id == widget.initialEquipmentId);
          } catch (e) { print("Initial equipment ID not found in list"); }
        }

      } else { throw Exception('Failed to load equipment list'); }
      setState(() { _isFetchingData = false; });
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'loading equipment list');
      setState(() { _isFetchingData = false; });
    }
  }

  Future<void> _recordMovement() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEquipment == null || _selectedType == null) {
      setState(() { _errorMessage = 'Please select equipment and movement type.'; });
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    Map<String, dynamic> movementData = {
      'equipmentId': _selectedEquipment!.id,
      'quantity': int.tryParse(_quantityController.text.trim()) ?? 0,
      'type': _selectedType!.name,
      'movementDate': _movementDate != null ? _dateFormatter.format(_movementDate!) : null,
      'reason': _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      // 'performedByUserId' is usually set by backend based on logged-in user
    };

    try {
      print('Recording stock movement: $movementData');
      // **VERIFY/MODIFY** POST endpoint
      final response = await _dio.post('/api/equipment/movements', data: movementData);

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Stock movement recorded successfully!'), backgroundColor: Colors.green) );
        Navigator.pop(context, true); // Signal success
      } else {
        _handleApiError(response, 'Failed to record movement');
      }
    } catch (e) {
      if (!mounted) return;
      _handleGenericError(e, 'recording movement');
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }


  // --- Error Handling Helpers ---
  void _handleApiError(Response? response, String defaultMessage) {/*... Same ...*/}
  void _handleGenericError(Object e, String action) {/*... Same ...*/}

  // --- Date Picker Logic ---
  Future<void> _selectMovementDate(BuildContext context) async {
    // ... (Standard Date Picker Logic for _movementDate) ...
    final DateTime initial = _movementDate ?? DateTime.now();
    final DateTime first = DateTime.now().subtract(Duration(days: 90)); // Allow past 90 days?
    final DateTime last = DateTime.now().add(Duration(days: 1)); // Allow up to tomorrow?
    final DateTime? picked = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (picked != null && picked != _movementDate && mounted) { setState(() { _movementDate = picked; }); }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Stock Movement'), backgroundColor: Colors.blueGrey),
      body: _isFetchingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<DropdownItem>(
                value: _selectedEquipment,
                items: _equipmentItems.isEmpty ? [DropdownMenuItem(child: Text("Loading..."), value: null)] : _equipmentItems.map((eq) => DropdownMenuItem(value: eq, child: Text(eq.name))).toList(),
                onChanged: (v){setState(()=>_selectedEquipment=v);},
                decoration: InputDecoration(labelText: 'Equipment Item *', border: OutlineInputBorder(), hintText: _equipmentItems.isEmpty ? 'No equipment found' : null),
                validator: (v)=>v==null?'Required':null,
                isExpanded: true,
                disabledHint: Text("Loading Equipment..."),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<MovementType>(
                value: _selectedType,
                items: MovementType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                onChanged: (v){setState(()=>_selectedType=v);},
                decoration: InputDecoration(labelText: 'Movement Type *', border: OutlineInputBorder()),
                validator: (v)=>v==null?'Required':null,
              ),
              SizedBox(height: 12),
              TextFormField(controller: _quantityController, decoration: InputDecoration(labelText: 'Quantity *', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator:(v)=> v==null||v.isEmpty||int.tryParse(v)==null||int.parse(v)<=0 ?'Required positive integer':null),
              SizedBox(height: 12),
              Row(children: [ Expanded(child: InputDecorator(decoration: InputDecoration(labelText: 'Movement Date *', border: OutlineInputBorder()), child: Text(_movementDate != null ? _dateFormatter.format(_movementDate!) : 'Select Date'))), IconButton(icon: Icon(Icons.calendar_month), onPressed:()=> _selectMovementDate(context))]),
              SizedBox(height: 12),
              TextFormField(controller: _reasonController, decoration: InputDecoration(labelText: 'Reason (Optional)', border: OutlineInputBorder()), maxLines: 2),
              SizedBox(height: 24),
              if (_errorMessage != null) Padding(  padding: EdgeInsets.symmetric(vertical: 16.0), child: Center(child: Text("An Error has accured.")) ),
              ElevatedButton( onPressed: _isLoading ? null : _recordMovement, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueGrey), child: _isLoading ? SizedBox(/*...loading...*/) : Text('Record Movement')),

            ],
          ),
        ),
      ),
    );
  }
}