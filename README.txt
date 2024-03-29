=== ucpclient ===

Klient protokołu UCP. Wszystkie parametry są opcjonalne:

 * PeerAddr=<host>
 * PeerPort=<port>
 * Listen=<1, jeśli program ma nasłuchiwać na porcie zamiast się łączyć>
 * LocalAddr=<adres lokalny dla nasłuchiwanego połączenia>
 * LocalPort=<port lokalny na którym nasłuchiwane są połączenia>
 * pwd=<hasło wysłane jako O/60 przed właściwą ramką>
 * Requests=<ilość wysłanych ramek, 1 domyślnie>
 * Window=<wielkość okna, 1 domyślnie>
 * Delay=<ilość sekund pomiędzy ramkami (dokładność do ms), 0 domyślnie>
 * Sleep=<ilość sekund po ostatniej ramce, przed zakończeniem programu, 0 domyślnie>
 * Benchmark=<1, jeśli program ma pokazać czas od wysłania pierwszej ramki do odebrania ostatniej>
 * op=<typ ramki, 51 domyślnie>
 * adc=<msisdn docelowy>
 * oadc=<msisdn lub nadpis nadawcy>
 * amsg=<treść komunikatu, TestMe domyślnie>

Zdiagnozowanie referencyjnego LA:

 $ ucpclient.pl PeerAddr=10.12.16.99 PeerPort=5638 pwd=pwd amsg=AnswerMe oadc=6638 adc=500000 pwd=pwd Requests=1 Sleep=1
 Mon Jun 12 18:06:12 2006 C >>> [00/00045/O/60/6638/6/5/1/707764//0100//////71]
 Mon Jun 12 18:06:12 2006 C <<< [00/00019/R/60/A//6D]
 Mon Jun 12 18:06:13 2006 C >>> [00/00076/O/51/500000/6638/////////////////3//416E737765724D65/////////////7B]
 Mon Jun 12 18:06:13 2006 C <<< [00/00039/R/51/A//500000:120606180613/5F]
 Mon Jun 12 18:06:13 2006 C <<< [00/00099/O/52/6638/500000////////////0000/120606180613////3//52653A416E737765724D65///0//////////19]
 Mon Jun 12 18:06:13 2006 C >>> [00/00046/R/52/N/02/53796E746178206572726F72/24]
 Mon Jun 12 18:06:15 2006 C *** [2 msgs sent, 1 msgs responsed, 1 msgs ack, 1 msgs unknown]

=== fakesmsc ===

Serwer protokołu UCP, który odpowiada ramkami R/51 na ramki O/51 i dodatkowo
wysyła ramkę O/52 jeżeli amsg=AnswerMe. Ponadto odpowiada R/60/A na ramkę
O/60 jeśli pwd=pwd, albo R/60/N jeżeli pwd jest inne.

Dzięki temu narzędziu można sterminować połączenie na UCPGW bez
konieczności podłączenia się do prawdziwego SMSC. W szczególności
działa takie zestawienie: ucpclient <> UCPGW <> fakesmsc

Przykład:

 $ fakesmsc.pl Listen=1 LocalAddr=127.0.0.1 LocalPort=12345 DebugLevel=4
