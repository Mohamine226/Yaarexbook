import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api.dart';
import '../widgets/common.dart';

/// Confirmation de l'email à l'inscription : le compte n'est créé qu'avec le bon code.
class VerifyRegisterPage extends StatefulWidget {
  final String nom;
  final String prenom;
  final String email;
  final String password;
  final String telephone;
  final String pays;
  final String profession;

  const VerifyRegisterPage({
    super.key,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.password,
    this.telephone = '',
    this.pays = '',
    this.profession = '',
  });

  @override
  State<VerifyRegisterPage> createState() => _VerifyRegisterPageState();
}

class _VerifyRegisterPageState extends State<VerifyRegisterPage> {
  static const _length = 6;
  static const _cooldown = 60;

  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  bool _resending = false;

  Timer? _timer;
  int _seconds = _cooldown;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _seconds = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_seconds <= 1) {
        t.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != _length) {
      showMsg(context, 'Saisissez le code à 6 chiffres.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.register(
        nom: widget.nom,
        prenom: widget.prenom,
        email: widget.email,
        password: widget.password,
        telephone: widget.telephone,
        pays: widget.pays,
        profession: widget.profession,
        code: code,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.popUntil(context, (r) => r.isFirst); // retour à la connexion
      messenger.showSnackBar(
        const SnackBar(content: Text('Compte créé : connectez-vous.')),
      );
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      await Api.sendRegisterCode(widget.email);
      if (mounted) {
        _code.clear();
        showMsg(context, 'Un nouveau code a été envoyé.');
        _startCountdown();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _resending = false);
  }

  String get _timeLeft {
    final m = _seconds ~/ 60;
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _codeBoxes() {
    final scheme = Theme.of(context).colorScheme;
    final text = _code.text;
    final current = text.length.clamp(0, _length - 1);
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < _length; i++)
                Container(
                  width: 46,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_focus.hasFocus && i == current) ? scheme.primary : Colors.grey.shade400,
                      width: (_focus.hasFocus && i == current) ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    i < text.length ? text[i] : '',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _code,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_length),
                ],
                enableInteractiveSelection: false,
                showCursor: false,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmation')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(Icons.mark_email_unread_outlined, size: 42, color: scheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Confirmez votre email',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Nous avons envoyé un code à 6 chiffres à\n${widget.email}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 28),
            _codeBoxes(),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: (_busy || _code.text.length != _length) ? null : _verify,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Créer mon compte'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Pas reçu ?', style: TextStyle(color: Colors.grey.shade700)),
                if (_seconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      'Renvoyer dans $_timeLeft',
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  TextButton(
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 36)),
                    onPressed: _resending ? null : _resend,
                    child: const Text('Renvoyer', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}