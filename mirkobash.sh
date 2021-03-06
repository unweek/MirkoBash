#!/bin/bash

author="Bielecki & unweek"
version="0.0.11"
lastupdate="22.08.2019"

## Changelog
#
# 0.0.9 - added checking error function. Redesigned @unweek code, inserting tabs instead of spaces, fixing comments, etc.
# 0.0.8 - added browsing newest entries - thanks to @unweek
# 0.0.7 - added liking entries while reading hot pages
# 0.0.6 - reading hot logic rebuilded, fixed no "body" issue
# 0.0.5 - infos about entries and coloring some shit
# 0.0.4 - moving hot to hot_stats; hot function is now for reading mirko
# 0.0.3 - moved config data to ~/.config/mirkobash/, added polish comments
# 0.0.2 - added hot page scrapping
# 0.0.1 - initial version - post and quick login with userkey updating
#
##

main() {	# funkcja startowa, wywoływana na końcu skryptu, by wpierw załadować ustawienia

if [ -n "$1" ]; then		# użytkownik podał parametr, więc sprawdźmy który to i przenieśmy do odpowiedniej funkcji
	case "$1" in
	--login)	login
		;;
	--post)	shift && post "$@"
		;;
	--hot)	shift && hot "$@"
		;;
	--hot_stats) shift && hot_stats "$@"
		;;
	--newest)	newest
		;;
	--noti)		noti
		;;
	--observed)		observed
		;;
	--help | --usage | -h | -\? | -u)	usage; exit 0
		;;
	* )	usage; exit 1
		;;
	esac
	shift
fi
}


usage() {	# pomoc
printf "%b\n" "MirkoBash v$version by $author" "Last updated: $lastupdate\n"
printf "%s\n" "Dostępne opcje:" \
	"--login: logowanie użytkownika, renowacja klucza" \
	"--post \"(zawartość)\": wrzuca na mirko post z podaną zawartością" \
	"--hot (strona) (czas: 6, 12 lub 24): zwraca ID, datę i ilość plusów postów z gorących"\
	"--newest: najnowsze wpisy z mikrobloga"\
	"--noti: zwraca powiadomienia (zawołania, prywatne wiadomości)"\
	"--observed: obserwowane wpisy"
}

## Sprawdzamy czy config w ogóle istnieje
if [ ! -d "$HOME/.config/mirkobash" ]; then	# folder instnieje?
	mkdir "$HOME/.config/mirkobash"
else	# jeśli nie ma configu, to stwórzmy nowy
	if [ ! -s "$HOME/.config/mirkobash/mirkobash.conf" ]; then
		printf "
## Config for MirkoBash
secret=\"\"
appkey=\"\"
token=\"\"
userkey=\"\"
" > "$HOME/.config/mirkobash/mirkobash.conf"
	fi
fi

if [ -z "$1" ]; then usage; fi	# sprawdzamy czy użytkownik podał parametry, jeśli nie to wyrzucamy usage

## Load settings:
. "$HOME/.config/mirkobash/mirkobash.conf"		# ładujemy config
if [ -z "$secret" -o -z "$appkey" -o -z "$token" ]; then	#sprawdzamy czy użytkownik uzupełnił config swoimi danymi
	echo "Uzupelnij konfigurację w ~/.config/mirkobash/mirkobash.conf, wpisujac dane z tworzenia aplikacji wykopu"
	exit 1
fi


sign() {	# podpisywanie żądań, wywołując funkcję zyskujemy czytelność
md5all=$(echo -n "$secret$url$data2" | md5sum | awk '{print $1}')
}


check_errors() {	# sprawdzanie czy wystąpił błąd
if grep -q "error\":" <<< "$content"; then	# jeśli wyłapiemy błąd, należy o tym poinformować użytkownika
	errorcode=$(grep -oP '(?<="code":)[^,]*' <<< "$content")	# pobieranie errorcode
	errormsg_en=$(grep -oP '(?<="message_en":")[^"]*' <<< "$content")	# pobieranie angielskiej wiadomości błędu
	errormsg_pl=$(grep -oP '(?<="message_pl":")[^"]*' <<< "$content")	# pobieranie polskiej wiadomości błędu
	printf "%b\n" "Wystąpił błąd!" "Kod błędu: $errorcode" "Treść błędu (en): $errormsg_en" "Treść błędu: $errormsg_pl"	# powiadomienie o błędzie użytkownika
	exit "$errorcode"	# zwrot kodu błędu z wykopu do użytkownika - możliwie przydatne przy skryptach
fi
}


like() {	# dawanie plusów wpisom
url="https://a2.wykop.pl/Entries/VoteUp/$id/appkey/$appkey/token/$token/userkey/$userkey/"
sign
curl -s -H "apisign: $md5all" -X GET "$url" > /dev/null 2>&1	# curl zwraca listę wszystkich plusujących
check_errors
echo "Zaplusowano powyższy wpis"	# nie wiem jeszcze jak sprawdzać czy się powiodło. Czy powyższa funkcja rozwiązuje problem? Być może tak
sleep 1	# damy użytkownikowi chwilę, żeby wiedział że się udało
}


hot() {		# funkcja wyświetlania gorących do czytania
if [ -z "$1" -o -z "$2" ]; then	# jeśli użytkownik nie podał parametrów, odeślij do usage
	usage
	exit 1
fi
page="$1"	# pobieramy stronę z parametru pierwszego
period="$2"	# pobieramy zakres czasu z parametru drugiego
url="https://a2.wykop.pl/Entries/Hot/page/$page/period/$period/appkey/$appkey/token/$token/userkey/$userkey/"   # tutaj wcześniej nie było podpisywania kluczem i wyrzucało niepoprawnie podpisane zapytanie
sign
content=$(curl -s -H "apisign: $md5all" -X GET "$url" | sed 's/,{"id"/\n{"id"/g')	# ładujemy cały content i dzielimy zwrotkę na linie, po jednym wpisie każda
check_errors
content_count=$(wc -l <<< "$content")	# liczymy ilość wpisów po ilości linii po podziale
for ((i = 1; i <= "$content_count"; i++)); do	# otwieramy pętlę przez wszystkie wpisy
	entry=$(sed -n "${i}p" <<< "$content")	# ładujemy n-ty wpis jako pojedynczy wpis (a nie jako grupa)
	id=$(grep -oP '((?<="id":)[^,]*)' <<< "$entry")	# ładujemy ID wpisu
	date=$(grep -oP '((?<="date":")[^"]*)' <<< "$entry")	# ładujemy datę wpisu
	votes=$(grep -oP '((?<="vote_count":)[^,]*)' <<< "$entry")	# ładujemy ilość plusów
	body=$(grep -oP '((?<="body":")(\\"|[^"])*)' <<< "$entry" | sed 's,<br \\/>,,g;s,<a href=[^>]*>,,g;s,<\\/a>,,g;s,&quot;,",g' )	# ładujemy treść wpisu, jeśli jest ( ͡° ͜ʖ ͡°)
	author=$(grep -oP '((?<="login":")(\\"|[^"])*)' <<< "$entry")	# ładujemy autora wpisu
	embed=$(grep -oP '((?<="url":")(\\"|[^"])*)' <<< "$entry" | sed 's,\\,,g')	# ładujemy załącznik, jeśli jest
	comments=$(grep -oP '((?<="comments_count":)[^,]*)' <<< "$entry")

	printf "\n\033[1;33m%b\033[0;36m%b" "ID wpisu: " "$id" "Autor: " "$author" "Data: " "$date" "Ilość plusów: " "$votes" "Ilość komentarzy: " "$comments"	# wypisywanie informacji o wpisie
	printf "\033[0m"	# mały reset koloru
	if [ -n "$body" ]; then	# jeśli body nie jest puste...
		printf "\n\n%b\n" "$body" # ...wypisujemy treść wpisu
	else	# a jeśli jest
		printf "\n\n\033[1;31m%b\033[0m\n" "Ten wpis nie zawiera treści :("
	fi
	if [ -n "$embed" ]; then	# sprawdzamy czy jest załącznik, np. jakieś zdjęcie
		printf "\n\033[0;93m%b\033[0;36m%b\033[0m\n" "Ten wpis zawiera załącznik dostępny tutaj: " "$embed"
	fi
	echo ""; read -e -p "Czytać dalej? (Y/n/+)  " YN	# pytamy się użytkownika czy chce czytać dalej
	[[ "$YN" == "n" || "$YN" == "N" ]] && break	# jeśli user stwierdzi że dość, to przerwij pętlę
	[[ "$YN" == "+" ]] && like
done
exit 0
}

hot_stats() {		# funkcja wyświetlania statystyk gorących
if [ -z "$1" -o -z "$2" ]; then	# jeśli użytkownik nie podał parametrów, odeślij do usage
	usage
	exit 1
fi
page="$1"	# pobieramy stronę z parametru pierwszego
period="$2"	# pobieramy zakres czasu z parametru drugiego
url="https://a2.wykop.pl/Entries/Hot/page/$page/period/$period/appkey/$appkey/token/$token/userkey/$userkey/"
sign
if [ "$3" != "-s" ]; then	# jako trzeci parametr możemy dodać "-s", co wyciszy nagłówek
	printf "%b" "ID\t\t" "Date - time\t" "Votes\n"	# jeśli parametru -s nie ma, wyświetl nagłówek
fi
curl -s -H "apisign: $md5all" -X GET "$url" | grep -oP '((?<="id":)[^,]*|(?<="date":")[^"]*|(?<="vote_count":)[^,]*)' | sed 's/$/ /g' | awk 'ORS=NR%3?FS:RS'	# pobieramy i wyciągamy potrzebne dane, wyświetlamy w trzech kolumnach

###
# do przerobienia powyższy curl - trzeba uruchomić obsługę błędów, a także przy tym obsłużyć parametrs -s (silent), przydatny w skryptach
###

exit 0
}

newest() {	# funkcja wyświetlania najnowszych wpisów do czytania	### by @unweek
page=""	# pobieramy stronę z parametru. Spróbujemy przekazać pusty parametr, bo i tak api to olewa
url="https://a2.wykop.pl/Entries/Stream/page/$page/firstid/$1/appkey/$appkey/token/$token/userkey/$userkey/"
sign
content=$(curl -s -H "apisign: $md5all" -X GET "$url" | sed 's/,{"id"/\n{"id"/g')	# ładujemy cały content i dzielimy zwrotkę na linie, po jednym wpisie każda
check_errors
content_count=$(wc -l <<< "$content")	# liczymy ilość wpisów po ilości linii po podziale
printf "\n\033[1;33m%b\033[0;36m%b\033[0m\n" "Pobranych wpisów: " "$content_count"	# informujemy użytkownika o ilości pobranych wpisów, bo jest ich więcej niż w gorących
sleep 1	# dajemy użytkownikowi chwilę, żeby zapoznał się z informacją
for ((i = 1; i <= "$content_count"; i++)); do	# otwieramy pętlę przez wszystkie wpisy
	entry=$(sed -n "${i}p" <<< "$content")	# dzielenie wpisów na pojedyńcze
	id=$(grep -oP '((?<="id":)[^,]*)' <<< "$entry")	# ID wpisu
	date=$(grep -oP '((?<="date":")[^"]*)' <<< "$entry")	# data
	votes=$(grep -oP '((?<="vote_count":)[^,]*)' <<< "$entry")	# ilość plusów
	body=$(grep -oP '((?<="body":")(\\"|[^"])*)' <<< "$entry" | sed 's,<br \\/>,,g;s,<a href=[^>]*>,,g;s,<\\/a>,,g;s,&quot;,",g' )	# treść wpisu
	author=$(grep -oP '((?<="login":")(\\"|[^"])*)' <<< "$entry")	# autor
	embed=$(grep -oP '((?<="url":")(\\"|[^"])*)' <<< "$entry" | sed 's,\\,,g')	# dodawanie załącznika
	comments=$(grep -oP '((?<="comments_count":)[^,]*)' <<< "$entry")
    #tutaj miało być rozróżnianie płci, ale za każdym razem api zwraca "male"
    #jeszcze chciałem dać kolory do nicków, ale nie wiem, jak się je daje

	printf "\n\033[1;33m%b\033[0;36m%b" "ID wpisu: " "$id" "Autor: " "$author" "Data: " "$date" "Ilość plusów: " "$votes" "Ilość komentarzy: " "$comments"	# wypisywanie informacji o wpisie
	printf "\033[0m"	# resetowanie koloru
	if [ -n "$body" ]; then	# sprawdzanie, body nie jest puste
		printf "\n\n%b\n" "$body"	# wypisywanie treści wpisu
	else	# body jest puste
		printf "\n\n\033[1;31m%b\033[0m\n" "Ten wpis nie zawiera treści :("
	fi
	if [ -n "$embed" ]; then	# sprawdzanie czy jest załącznik
		printf "\n\033[0;93m%b\033[0;36m%b\033[0m\n" "Ten wpis zawiera załącznik dostępny tutaj: " "$embed"
	fi
	echo ""; read -e -p "Czytać dalej? (Y/n/+)  " YN	# pytamy się użytkownika czy chce czytać dalej
	[[ "$YN" == "n" || "$YN" == "N" ]] && break	# jeśli user stwierdzi że dość, to przerwij pętlę
	[[ "$YN" == "+" ]] && like	# plusowanie
done
exit 0
}

login() {	# funkcja logująca użytkownika i dorzucająca userkey do configu
if [ -s "$HOME/.config/mirkobash/login.conf" ]; then	# jeśli użytkownik wprowadził tam swoje dane logowania, wykorzystamy je
	. "$HOME/.config/mirkobash/login.conf"
else		# jeśli nie, pytamy użytkownika o login i hasło
	echo "Enter login:"
	read -s LOGIN
	echo "Enter password:"
	read -s PASSWORD
fi

url="https://a2.wykop.pl/Login/Index/accountkey/$token/appkey/$appkey/"
data="login=$LOGIN&password=$PASSWORD&accountkey=$token"
data2="$LOGIN,$PASSWORD,$token"
sign
newuserkey=$(curl -s -H "apisign: $md5all" -X POST --data "$data" "$url" | grep -oP '(?<="userkey":")[^"]*')	# wyciągamy nowy userkey
###
# czy tutaj też powinniśmy obsłużyć błędy? Poniżej zwracamy tylko uogólniony błąd, jeśli nie dostaniemy userkey
###
if [ -z "$newuserkey" ]; then	# jeśli curl nie zwróci userkey, wyświetlamy że był błąd
	echo "Error during login"
	exit 1
else
	sed -i 's/^userkey=".*"/userkey="'"$newuserkey"'"/' "$HOME/.config/mirkobash/mirkobash.conf"	# a jeśli zwrócił, to wrzucamy nowy klucz do configu
	echo "Logged in successfully"
	exit 0
fi
}

noti() {	# funkcja służąca do czytania powiadomień	### by @unweek
page=""	# parametr musi być #pdk
url="https://a2.wykop.pl/Notifications/Index/page/$page/firstid/$firstid/appkey/$appkey/token/$token/userkey/$userkey/"
sign
content=$(curl -s -H "apisign: $md5all" -X GET "$url" | sed 's/,{"id"/\n{"id"/g')	# ładujemy cały content i dzielimy zwrotkę na linie
check_errors
content_count=$(wc -l <<< "$content")	# liczenie powiadomień
for ((i = 1; i <= "$content_count"; i++)); do	# otwieramy pętlę
	entry=$(sed -n "${i}p" <<< "$content")	# dzielenie powiadomień na pojedyńcze
	date=$(grep -oP '((?<="date":")[^"]*)' <<< "$entry")	# data
	body=$(grep -oP '((?<="body":")(\\"|[^"])*)' <<< "$entry" | sed 's,<br \\/>,,g;s,<a href=[^>]*>,,g;s,<\\/a>,,g;s,&quot;,",g' )	# treść wpisu
	author=$(grep -oP '((?<="login":")(\\"|[^"])*)' <<< "$entry")	# autor
	embed=$(grep -oP '((?<="url":")(\\"|[^"])*)' <<< "$entry" | sed 's,\\,,g')	# dodawanie załącznika
	# tutaj miałem dodać sprawdzanie, czy powiadomienie zostało już wcześciej odczytane, ale po kilku godzinach męczenia się z kodem odpuściłem

	printf "\n\033[1;33m%b\033[0;36m%b" "Od: " "$author" "Data: " "$date"	# wypisywanie informacji
	printf "\033[0m"	# resetowanie koloru
	if [ -n "$body" ]; then	# sprawdzanie, body nie jest puste
		printf "\n\n%b\n" "$body"	# wypisywanie treści wpisu
	else	# body jest puste
		printf "\n\n\033[1;31m%b\033[0m\n" "Ten wpis nie zawiera treści :("
	fi
	if [ -n "$embed" ]; then	# sprawdzanie linku do przeczytania
		printf "\n\033[0;93m%b\033[0;36m%b\033[0m\n" "Ta odpowiedź jest dostępna tutaj: " "$embed"
	fi
	echo ""; read -e -p "Czytać dalej? (Y/n)  " YN	# pytamy się użytkownika czy chce czytać dalej
	[[ "$YN" == "n" || "$YN" == "N" ]] && break	# jeśli user stwierdzi że dość, to przerwij pętlę
done
exit 0
}

#	tutaj miała byc funkcja czytania powiadomień z tagów wyglądająca jak ta wyżej, ale Maciej znowu coś zepsuł

#	tutaj z kolei miał być Mój Wykop, ale gdy spróbuje wczytać znalezisko, wykrzacza się

observed() {	# funkcja wyświetlania obserwowanych wpisów		### by @unweek
page=""	# pobieramy stronę z parametru. Spróbujemy przekazać pusty parametr, bo i tak api to olewa
url="https://a2.wykop.pl/Entries/Observed/page/$page/appkey/$appkey/token/$token/userkey/$userkey/"
sign
content=$(curl -s -H "apisign: $md5all" -X GET "$url" | sed 's/,{"id"/\n{"id"/g')	# ładujemy cały content i dzielimy zwrotkę na linie, po jednym wpisie każda
check_errors
content_count=$(wc -l <<< "$content")	# liczymy ilość wpisów po ilości linii po podziale
printf "\n\033[1;33m%b\033[0;36m%b\033[0m\n" "Pobranych wpisów: " "$content_count"	# informujemy użytkownika o ilości pobranych wpisów, bo jest ich więcej niż w gorących
sleep 1	# dajemy użytkownikowi chwilę, żeby zapoznał się z informacją
for ((i = 1; i <= "$content_count"; i++)); do	# otwieramy pętlę przez wszystkie wpisy
	entry=$(sed -n "${i}p" <<< "$content")	# dzielenie wpisów na pojedyńcze
	id=$(grep -oP '((?<="id":)[^,]*)' <<< "$entry")	# ID wpisu
	date=$(grep -oP '((?<="date":")[^"]*)' <<< "$entry")	# data
	votes=$(grep -oP '((?<="vote_count":)[^,]*)' <<< "$entry")	# ilość plusów
	body=$(grep -oP '((?<="body":")(\\"|[^"])*)' <<< "$entry" | sed 's,<br \\/>,,g;s,<a href=[^>]*>,,g;s,<\\/a>,,g;s,&quot;,",g' )	# treść wpisu
	author=$(grep -oP '((?<="login":")(\\"|[^"])*)' <<< "$entry")	# autor
	embed=$(grep -oP '((?<="url":")(\\"|[^"])*)' <<< "$entry" | sed 's,\\,,g')	# dodawanie załącznika
	comments=$(grep -oP '((?<="comments_count":)[^,]*)' <<< "$entry")

	printf "\n\033[1;33m%b\033[0;36m%b" "ID wpisu: " "$id" "Autor: " "$author" "Data: " "$date" "Ilość plusów: " "$votes" "Ilość komentarzy: " "$comments"	# wypisywanie informacji o wpisie
	printf "\033[0m"	# resetowanie koloru
	if [ -n "$body" ]; then	# sprawdzanie, body nie jest puste
		printf "\n\n%b\n" "$body"	# wypisywanie treści wpisu
	else	# body jest puste
		printf "\n\n\033[1;31m%b\033[0m\n" "Ten wpis nie zawiera treści :("
	fi
	if [ -n "$embed" ]; then	# sprawdzanie czy jest załącznik
		printf "\n\033[0;93m%b\033[0;36m%b\033[0m\n" "Ten wpis zawiera załącznik dostępny tutaj: " "$embed"
	fi
	echo ""; read -e -p "Czytać dalej? (Y/n/+)  " YN	# pytamy się użytkownika czy chce czytać dalej
	[[ "$YN" == "n" || "$YN" == "N" ]] && break	# jeśli user stwierdzi że dość, to przerwij pętlę
	[[ "$YN" == "+" ]] && like	# plusowanie
done
exit 0
}

post() {	# funkcja pozwalająca na zapostowanie tekstu na mirko
if [ -z "$1" ]; then usage; fi

tresc="$1"	# pierwszy parametr to treść postu - musi być podany w cudzysłowiu
embed="$2"
data="body=$tresc&embed=$embed"
data2="$tresc,$embed"
url="https://a2.wykop.pl/entries/add/appkey/$appkey/token/$token/userkey/$userkey/"
sign
content=$(curl -s -H "apisign: $md5all" -X POST --data "$data" "$url")	# generalnie pobieramy info czy się udało, czy wystąpił błąd
check_errors
echo "Done :)"
exit 0
}

main "$@"	# po załadowaniu wszystkich configów etc, przenosimy użytkownika do ustalania jaki parametr wpisał
exit 2 # na wszelki wypadek, gdyby użytkownik przypadkiem opuścił ifa
